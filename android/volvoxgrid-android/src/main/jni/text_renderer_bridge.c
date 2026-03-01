#include <jni.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <math.h>

typedef void (*vv_measure_text_fn)(
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    float max_width,
    float* out_width, float* out_height,
    void* user_data
);

typedef float (*vv_render_text_fn)(
    uint8_t* buffer, int32_t buf_width, int32_t buf_height, int32_t stride,
    int32_t x, int32_t y, int32_t clip_x, int32_t clip_y, int32_t clip_w, int32_t clip_h,
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    uint32_t color,
    float max_width,
    void* user_data
);

typedef int32_t (*vv_set_text_renderer_fn)(
    int64_t grid_id,
    vv_measure_text_fn measure_fn,
    vv_render_text_fn render_fn,
    void* user_data
);

typedef int32_t (*vv_has_builtin_text_engine_fn)(void);

#define MASK_CACHE_CAPACITY 8192
#define MASK_CACHE_BUCKETS 2048

typedef struct MaskCacheEntry {
    uint32_t hash;
    uint8_t* text;
    int32_t text_len;
    uint8_t* font_name;
    int32_t font_name_len;
    float font_size;
    int32_t bold;
    int32_t italic;
    float max_width;

    int32_t mask_w;
    int32_t mask_h;
    int32_t mask_stride;
    float real_width;
    float real_height;
    uint8_t* mask_data;
    size_t mask_data_len;

    struct MaskCacheEntry* prev;
    struct MaskCacheEntry* next;
    struct MaskCacheEntry* hash_next;
} MaskCacheEntry;

typedef struct MaskCache {
    MaskCacheEntry* head;
    MaskCacheEntry* tail;
    int count;
    int capacity;
    pthread_mutex_t lock;
    MaskCacheEntry* buckets[MASK_CACHE_BUCKETS];
} MaskCache;

typedef struct RendererBinding {
    jobject callback_global;
    jmethodID measure_method;
    jmethodID rasterize_method;
    jbyteArray text_buffer;
    int32_t text_buffer_cap;
    jbyteArray font_buffer;
    int32_t font_buffer_cap;
    MaskCache mask_cache;
} RendererBinding;

typedef struct BindingNode {
    int64_t grid_id;
    RendererBinding* binding;
    struct BindingNode* next;
} BindingNode;

static JavaVM* g_vm = NULL;
static BindingNode* g_bindings = NULL;
static pthread_mutex_t g_bindings_lock = PTHREAD_MUTEX_INITIALIZER;

static void free_cache_entry(MaskCacheEntry* e) {
    if (e->text) free(e->text);
    if (e->font_name) free(e->font_name);
    if (e->mask_data) free(e->mask_data);
    free(e);
}

static void init_mask_cache(MaskCache* cache, int capacity) {
    cache->head = NULL;
    cache->tail = NULL;
    cache->count = 0;
    cache->capacity = capacity;
    memset(cache->buckets, 0, sizeof(cache->buckets));
    pthread_mutex_init(&cache->lock, NULL);
}

static void free_mask_cache(MaskCache* cache) {
    pthread_mutex_lock(&cache->lock);
    MaskCacheEntry* curr = cache->head;
    while (curr) {
        MaskCacheEntry* next = curr->next;
        free_cache_entry(curr);
        curr = next;
    }
    cache->head = NULL;
    cache->tail = NULL;
    cache->count = 0;
    memset(cache->buckets, 0, sizeof(cache->buckets));
    pthread_mutex_unlock(&cache->lock);
    pthread_mutex_destroy(&cache->lock);
}

static uint32_t compute_text_hash(
    const uint8_t* text, int32_t text_len,
    const uint8_t* font, int32_t font_len,
    float font_size, int32_t bold, int32_t italic, float max_width
) {
    uint32_t hash = 2166136261u;
    for (int32_t i = 0; i < text_len; i++) {
        hash ^= text[i];
        hash *= 16777619;
    }
    for (int32_t i = 0; i < font_len; i++) {
        hash ^= font[i];
        hash *= 16777619;
    }
    
    // Quantize to tenths to absorb minor floating point precision jitter.
    int32_t q_font_size = (int32_t)roundf(font_size * 10.0f);
    int32_t q_max_width = max_width > 0.0f ? (int32_t)roundf(max_width * 10.0f) : -1;

    hash ^= (uint32_t)q_font_size; hash *= 16777619;
    hash ^= (uint32_t)bold; hash *= 16777619;
    hash ^= (uint32_t)italic; hash *= 16777619;
    hash ^= (uint32_t)q_max_width; hash *= 16777619;
    return hash;
}

static int is_cache_match(MaskCacheEntry* e, uint32_t hash,
    const uint8_t* text, int32_t text_len,
    const uint8_t* font, int32_t font_len,
    float font_size, int32_t bold, int32_t italic, float max_width) {
    if (e->hash != hash) return 0;
    if (e->text_len != text_len || e->font_name_len != font_len) return 0;
    if (e->bold != bold || e->italic != italic) return 0;

    int32_t q_e_fs = (int32_t)roundf(e->font_size * 10.0f);
    int32_t q_fs = (int32_t)roundf(font_size * 10.0f);
    if (q_e_fs != q_fs) return 0;

    int32_t q_e_mw = e->max_width > 0.0f ? (int32_t)roundf(e->max_width * 10.0f) : -1;
    int32_t q_mw = max_width > 0.0f ? (int32_t)roundf(max_width * 10.0f) : -1;
    if (q_e_mw != q_mw) return 0;

    if (text_len > 0 && memcmp(e->text, text, text_len) != 0) return 0;
    if (font_len > 0 && memcmp(e->font_name, font, font_len) != 0) return 0;
    return 1;
}

static MaskCacheEntry* mask_cache_get(MaskCache* cache, uint32_t hash,
    const uint8_t* text, int32_t text_len,
    const uint8_t* font, int32_t font_len,
    float font_size, int32_t bold, int32_t italic, float max_width) {
    
    int bucket_index = hash % MASK_CACHE_BUCKETS;
    MaskCacheEntry* curr = cache->buckets[bucket_index];
    while (curr) {
        if (is_cache_match(curr, hash, text, text_len, font, font_len, font_size, bold, italic, max_width)) {
            // Move to front of LRU list (head)
            if (curr != cache->head) {
                if (curr->prev) curr->prev->next = curr->next;
                if (curr->next) curr->next->prev = curr->prev;
                if (curr == cache->tail) cache->tail = curr->prev;
                
                curr->next = cache->head;
                curr->prev = NULL;
                if (cache->head) cache->head->prev = curr;
                cache->head = curr;
            }
            return curr;
        }
        curr = curr->hash_next;
    }
    return NULL;
}

static void mask_cache_remove_from_hash(MaskCache* cache, MaskCacheEntry* e) {
    int bucket_index = e->hash % MASK_CACHE_BUCKETS;
    MaskCacheEntry* curr = cache->buckets[bucket_index];
    MaskCacheEntry* prev = NULL;
    while (curr) {
        if (curr == e) {
            if (prev) prev->hash_next = curr->hash_next;
            else cache->buckets[bucket_index] = curr->hash_next;
            break;
        }
        prev = curr;
        curr = curr->hash_next;
    }
}

static void mask_cache_evict_tail(MaskCache* cache) {
    if (!cache->tail) return;
    MaskCacheEntry* to_evict = cache->tail;
    cache->tail = to_evict->prev;
    if (cache->tail) cache->tail->next = NULL;
    else cache->head = NULL;
    
    mask_cache_remove_from_hash(cache, to_evict);
    free_cache_entry(to_evict);
    cache->count--;
}

static void mask_cache_put(MaskCache* cache, uint32_t hash,
    const uint8_t* text, int32_t text_len,
    const uint8_t* font, int32_t font_len,
    float font_size, int32_t bold, int32_t italic, float max_width,
    int32_t mask_w, int32_t mask_h, int32_t mask_stride, float real_width, float real_height,
    const uint8_t* mask_data, size_t mask_data_len) {
    
    MaskCacheEntry* existing = mask_cache_get(cache, hash, text, text_len, font, font_len, font_size, bold, italic, max_width);
    if (existing) {
        if (mask_data != NULL && existing->mask_data == NULL && mask_data_len > 0) {
            existing->mask_data = (uint8_t*)malloc(mask_data_len);
            if (existing->mask_data) {
                memcpy(existing->mask_data, mask_data, mask_data_len);
                existing->mask_data_len = mask_data_len;
                existing->mask_w = mask_w;
                existing->mask_h = mask_h;
                existing->mask_stride = mask_stride;
            }
        }
        return;
    }

    MaskCacheEntry* e = (MaskCacheEntry*)calloc(1, sizeof(MaskCacheEntry));
    if (!e) return;

    e->hash = hash;
    e->text_len = text_len;
    if (text_len > 0) {
        e->text = (uint8_t*)malloc(text_len);
        if (!e->text) { free_cache_entry(e); return; }
        memcpy(e->text, text, text_len);
    }
    e->font_name_len = font_len;
    if (font_len > 0) {
        e->font_name = (uint8_t*)malloc(font_len);
        if (!e->font_name) { free_cache_entry(e); return; }
        memcpy(e->font_name, font, font_len);
    }
    e->font_size = font_size;
    e->bold = bold;
    e->italic = italic;
    e->max_width = max_width;

    e->mask_w = mask_w;
    e->mask_h = mask_h;
    e->mask_stride = mask_stride;
    e->real_width = real_width;
    e->real_height = real_height;
    e->mask_data_len = mask_data_len;
    if (mask_data_len > 0 && mask_data != NULL) {
        e->mask_data = (uint8_t*)malloc(mask_data_len);
        if (!e->mask_data) { free_cache_entry(e); return; }
        memcpy(e->mask_data, mask_data, mask_data_len);
    }

    e->next = cache->head;
    if (cache->head) cache->head->prev = e;
    cache->head = e;
    if (!cache->tail) cache->tail = e;
    cache->count++;

    int bucket_index = hash % MASK_CACHE_BUCKETS;
    e->hash_next = cache->buckets[bucket_index];
    cache->buckets[bucket_index] = e;

    while (cache->count > cache->capacity && cache->tail) {
        mask_cache_evict_tail(cache);
    }
}

static void mask_cache_set_capacity(MaskCache* cache, int new_capacity) {
    cache->capacity = new_capacity < 0 ? 0 : new_capacity;
    while (cache->count > cache->capacity && cache->tail) {
        mask_cache_evict_tail(cache);
    }
}

static JNIEnv* get_env(int* should_detach) {
    if (should_detach != NULL) {
        *should_detach = 0;
    }
    if (g_vm == NULL) {
        return NULL;
    }
    JNIEnv* env = NULL;
    if ((*g_vm)->GetEnv(g_vm, (void**)&env, JNI_VERSION_1_6) == JNI_OK) {
        return env;
    }
    if ((*g_vm)->AttachCurrentThread(g_vm, &env, NULL) != JNI_OK) {
        return NULL;
    }
    if (should_detach != NULL) {
        *should_detach = 1;
    }
    return env;
}

static void free_binding(RendererBinding* binding) {
    if (binding == NULL) {
        return;
    }
    int should_detach = 0;
    JNIEnv* env = get_env(&should_detach);
    if (env != NULL) {
        if (binding->callback_global != NULL) {
            (*env)->DeleteGlobalRef(env, binding->callback_global);
        }
        if (binding->text_buffer != NULL) {
            (*env)->DeleteGlobalRef(env, binding->text_buffer);
        }
        if (binding->font_buffer != NULL) {
            (*env)->DeleteGlobalRef(env, binding->font_buffer);
        }
    }
    free_mask_cache(&binding->mask_cache);
    free(binding);
    if (should_detach && g_vm != NULL) {
        (*g_vm)->DetachCurrentThread(g_vm);
    }
}

static RendererBinding* take_binding_for_grid_locked(int64_t grid_id) {
    BindingNode* prev = NULL;
    BindingNode* node = g_bindings;
    while (node != NULL) {
        if (node->grid_id == grid_id) {
            RendererBinding* binding = node->binding;
            if (prev != NULL) {
                prev->next = node->next;
            } else {
                g_bindings = node->next;
            }
            free(node);
            return binding;
        }
        prev = node;
        node = node->next;
    }
    return NULL;
}

static void put_binding_for_grid_locked(int64_t grid_id, RendererBinding* binding) {
    BindingNode* node = (BindingNode*)calloc(1, sizeof(BindingNode));
    if (node == NULL) {
        return;
    }
    node->grid_id = grid_id;
    node->binding = binding;
    node->next = g_bindings;
    g_bindings = node;
}

static jbyteArray get_reusable_buffer(JNIEnv* env, jbyteArray* buffer, int32_t* cap, const uint8_t* ptr, int32_t len) {
    if (env == NULL) {
        return NULL;
    }
    int32_t needed = len > 0 ? len : 1;
    if (*buffer == NULL || *cap < needed) {
        if (*buffer != NULL) {
            (*env)->DeleteGlobalRef(env, *buffer);
            *buffer = NULL;
        }
        int32_t new_cap = needed < 256 ? 256 : (needed * 2);
        jbyteArray local_arr = (*env)->NewByteArray(env, new_cap);
        if (local_arr != NULL) {
            *buffer = (jbyteArray)(*env)->NewGlobalRef(env, local_arr);
            (*env)->DeleteLocalRef(env, local_arr);
            *cap = new_cap;
        } else {
            *cap = 0;
            return NULL;
        }
    }
    if (len > 0 && ptr != NULL) {
        (*env)->SetByteArrayRegion(env, *buffer, 0, len, (const jbyte*)ptr);
    }
    return *buffer;
}

static RendererBinding* create_binding(JNIEnv* env, jobject callback) {
    if (env == NULL || callback == NULL) {
        return NULL;
    }
    jclass cls = (*env)->GetObjectClass(env, callback);
    if (cls == NULL) {
        return NULL;
    }

    jmethodID measure_method = (*env)->GetMethodID(
        env,
        cls,
        "measureText",
        "([BI[BIFZZF)[F"
    );
    jmethodID rasterize_method = (*env)->GetMethodID(
        env,
        cls,
        "rasterizeText",
        "([BI[BIFZZF)[B"
    );

    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        (*env)->DeleteLocalRef(env, cls);
        return NULL;
    }

    if (measure_method == NULL || rasterize_method == NULL) {
        (*env)->DeleteLocalRef(env, cls);
        return NULL;
    }

    jobject callback_global = (*env)->NewGlobalRef(env, callback);
    (*env)->DeleteLocalRef(env, cls);
    if (callback_global == NULL) {
        return NULL;
    }

    RendererBinding* binding = (RendererBinding*)calloc(1, sizeof(RendererBinding));
    if (binding == NULL) {
        (*env)->DeleteGlobalRef(env, callback_global);
        return NULL;
    }
    binding->callback_global = callback_global;
    binding->measure_method = measure_method;
    binding->rasterize_method = rasterize_method;
    init_mask_cache(&binding->mask_cache, MASK_CACHE_CAPACITY);
    return binding;
}

static vv_set_text_renderer_fn resolve_set_text_renderer_fn(int64_t plugin_handle) {
    if (plugin_handle == 0) {
        return NULL;
    }
    return (vv_set_text_renderer_fn)dlsym((void*)(intptr_t)plugin_handle, "volvox_grid_set_text_renderer");
}

static vv_has_builtin_text_engine_fn resolve_has_builtin_text_engine_fn(int64_t plugin_handle) {
    if (plugin_handle == 0) {
        return NULL;
    }
    return (vv_has_builtin_text_engine_fn)dlsym((void*)(intptr_t)plugin_handle, "volvox_grid_has_builtin_text_engine");
}

static void bridge_measure_text(
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    float max_width,
    float* out_width, float* out_height,
    void* user_data
) {
    if (out_width == NULL || out_height == NULL) {
        return;
    }
    *out_width = 0.0f;
    *out_height = font_size > 0.0f ? (font_size * 1.2f) : 0.0f;

    RendererBinding* binding = (RendererBinding*)user_data;
    if (binding == NULL) {
        return;
    }

    uint32_t hash = compute_text_hash(text_ptr, text_len, font_name_ptr, font_name_len, font_size, bold, italic, max_width);
    
    pthread_mutex_lock(&binding->mask_cache.lock);
    MaskCacheEntry* cached = mask_cache_get(&binding->mask_cache, hash, text_ptr, text_len, font_name_ptr, font_name_len, font_size, bold, italic, max_width);

    if (cached != NULL) {
        *out_width = cached->real_width;
        *out_height = cached->real_height;
        pthread_mutex_unlock(&binding->mask_cache.lock);
        return;
    }
    pthread_mutex_unlock(&binding->mask_cache.lock);

    int should_detach = 0;
    JNIEnv* env = get_env(&should_detach);
    if (env == NULL) {
        return;
    }

    jbyteArray text_bytes = get_reusable_buffer(env, &binding->text_buffer, &binding->text_buffer_cap, text_ptr, text_len);
    jbyteArray font_bytes = get_reusable_buffer(env, &binding->font_buffer, &binding->font_buffer_cap, font_name_ptr, font_name_len);
    if (text_bytes == NULL || font_bytes == NULL) {
        if (should_detach && g_vm != NULL) (*g_vm)->DetachCurrentThread(g_vm);
        return;
    }

    jobject result = (*env)->CallObjectMethod(
        env,
        binding->callback_global,
        binding->measure_method,
        text_bytes,
        (jint)text_len,
        font_bytes,
        (jint)font_name_len,
        font_size,
        bold != 0 ? JNI_TRUE : JNI_FALSE,
        italic != 0 ? JNI_TRUE : JNI_FALSE,
        max_width
    );

    if (!(*env)->ExceptionCheck(env) && result != NULL) {
        jfloatArray dims = (jfloatArray)result;
        jsize len = (*env)->GetArrayLength(env, dims);
        if (len >= 2) {
            jfloat vals[2] = {0.0f, 0.0f};
            (*env)->GetFloatArrayRegion(env, dims, 0, 2, vals);
            *out_width = vals[0];
            *out_height = vals[1];

            pthread_mutex_lock(&binding->mask_cache.lock);
            mask_cache_put(
                &binding->mask_cache, hash,
                text_ptr, text_len, font_name_ptr, font_name_len,
                font_size, bold, italic, max_width,
                0, 0, 0, vals[0], vals[1], NULL, 0
            );
            pthread_mutex_unlock(&binding->mask_cache.lock);
        }
    } else if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
    }

    if (result != NULL) {
        (*env)->DeleteLocalRef(env, result);
    }

    if (should_detach && g_vm != NULL) {
        (*g_vm)->DetachCurrentThread(g_vm);
    }
}

static int32_t read_i32_le(const uint8_t* p) {
    if (p == NULL) {
        return 0;
    }
    uint32_t v =
        ((uint32_t)p[0]) |
        (((uint32_t)p[1]) << 8) |
        (((uint32_t)p[2]) << 16) |
        (((uint32_t)p[3]) << 24);
    return (int32_t)v;
}

static float read_f32_le(const uint8_t* p) {
    uint32_t bits = (uint32_t)read_i32_le(p);
    float out = 0.0f;
    memcpy(&out, &bits, sizeof(float));
    return out;
}

static void blend_glyph_mask_into_rgba(
    uint8_t* restrict target,
    int32_t target_width,
    int32_t target_height,
    int32_t stride,
    int32_t dst_x,
    int32_t dst_y,
    int32_t clip_x,
    int32_t clip_y,
    int32_t clip_w,
    int32_t clip_h,
    const uint8_t* restrict source_alpha,
    int32_t source_width,
    int32_t source_height,
    int32_t source_stride,
    uint32_t color,
    size_t target_size
) {
    if (target == NULL || source_alpha == NULL || source_width <= 0 || source_height <= 0) {
        return;
    }
    if (target_width <= 0 || target_height <= 0 || stride <= 0 || clip_w <= 0 || clip_h <= 0) {
        return;
    }

    int global_a = (int)((color >> 24) & 0xFF);
    if (global_a <= 0) {
        return;
    }
    int src_r = (int)((color >> 16) & 0xFF);
    int src_g = (int)((color >> 8) & 0xFF);
    int src_b = (int)(color & 0xFF);

    int x_min = dst_x > 0 ? dst_x : 0;
    int y_min = dst_y > 0 ? dst_y : 0;
    if (clip_x > x_min) x_min = clip_x;
    if (clip_y > y_min) y_min = clip_y;

    int x_max_a = dst_x + source_width;
    int x_max_b = clip_x + clip_w;
    int x_max = x_max_a < x_max_b ? x_max_a : x_max_b;
    if (x_max > target_width) x_max = target_width;

    int y_max_a = dst_y + source_height;
    // Keep engine semantics: clip_y is the top boundary, clip_h extends from
    // the draw origin (dst_y), not from clip_y.
    int y_max_b = dst_y + clip_h;
    int y_max = y_max_a < y_max_b ? y_max_a : y_max_b;
    if (y_max > target_height) y_max = target_height;

    if (x_max <= x_min || y_max <= y_min) {
        return;
    }

    for (int y_pos = y_min; y_pos < y_max; y_pos++) {
        int source_y = y_pos - dst_y;
        int src_row_offset = source_y * source_stride;
        size_t dst_row_offset = (size_t)y_pos * (size_t)stride;

        for (int x_pos = x_min; x_pos < x_max; x_pos++) {
            int source_x = x_pos - dst_x;
            int mask_alpha = source_alpha[src_row_offset + source_x] & 0xFF;
            if (mask_alpha <= 0) {
                continue;
            }
            int src_a = (mask_alpha * global_a + 127) / 255;
            if (src_a <= 0) {
                continue;
            }

            size_t offset = dst_row_offset + (size_t)x_pos * 4u;
            if (offset + 3u >= target_size) {
                continue;
            }

            if (src_a == 255) {
                target[offset] = (uint8_t)src_r;
                target[offset + 1] = (uint8_t)src_g;
                target[offset + 2] = (uint8_t)src_b;
                target[offset + 3] = 255;
            } else {
                int inv_a = 255 - src_a;
                int dst_r = target[offset] & 0xFF;
                int dst_g = target[offset + 1] & 0xFF;
                int dst_b = target[offset + 2] & 0xFF;
                int dst_a = target[offset + 3] & 0xFF;

                target[offset]     = (uint8_t)((src_r * src_a + dst_r * inv_a + 127) / 255);
                target[offset + 1] = (uint8_t)((src_g * src_a + dst_g * inv_a + 127) / 255);
                target[offset + 2] = (uint8_t)((src_b * src_a + dst_b * inv_a + 127) / 255);
                target[offset + 3] = (uint8_t)((255 * src_a + dst_a * inv_a + 127) / 255);
            }
        }
    }
}

static float bridge_render_text(
    uint8_t* buffer, int32_t buf_width, int32_t buf_height, int32_t stride,
    int32_t x, int32_t y, int32_t clip_x, int32_t clip_y, int32_t clip_w, int32_t clip_h,
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    uint32_t color,
    float max_width,
    void* user_data
) {
    RendererBinding* binding = (RendererBinding*)user_data;
    if (binding == NULL || buffer == NULL || buf_width <= 0 || buf_height <= 0 || stride <= 0) {
        return 0.0f;
    }

    uint32_t hash = compute_text_hash(text_ptr, text_len, font_name_ptr, font_name_len, font_size, bold, italic, max_width);
    
    pthread_mutex_lock(&binding->mask_cache.lock);
    MaskCacheEntry* cached = mask_cache_get(&binding->mask_cache, hash, text_ptr, text_len, font_name_ptr, font_name_len, font_size, bold, italic, max_width);

    if (cached != NULL) {
        if (cached->mask_data != NULL) {
            if (cached->mask_w > 0 && cached->mask_h > 0 && cached->mask_data_len > 0) {
                size_t target_size = (size_t)stride * (size_t)buf_height;
                blend_glyph_mask_into_rgba(
                    buffer, buf_width, buf_height, stride, x, y, clip_x, clip_y, clip_w, clip_h,
                    cached->mask_data, cached->mask_w, cached->mask_h, cached->mask_stride, color, target_size
                );
            }
            float rw = cached->real_width;
            pthread_mutex_unlock(&binding->mask_cache.lock);
            return rw;
        } else if (text_len == 0) {
            float rw = cached->real_width;
            pthread_mutex_unlock(&binding->mask_cache.lock);
            return rw;
        }
    }
    pthread_mutex_unlock(&binding->mask_cache.lock);

    int should_detach = 0;
    JNIEnv* env = get_env(&should_detach);
    if (env == NULL) {
        return 0.0f;
    }

    jbyteArray text_bytes = get_reusable_buffer(env, &binding->text_buffer, &binding->text_buffer_cap, text_ptr, text_len);
    jbyteArray font_bytes = get_reusable_buffer(env, &binding->font_buffer, &binding->font_buffer_cap, font_name_ptr, font_name_len);
    if (text_bytes == NULL || font_bytes == NULL) {
        if (should_detach && g_vm != NULL) (*g_vm)->DetachCurrentThread(g_vm);
        return 0.0f;
    }

    jobject result = (*env)->CallObjectMethod(
        env,
        binding->callback_global,
        binding->rasterize_method,
        text_bytes,
        (jint)text_len,
        font_bytes,
        (jint)font_name_len,
        font_size,
        bold != 0 ? JNI_TRUE : JNI_FALSE,
        italic != 0 ? JNI_TRUE : JNI_FALSE,
        max_width
    );

    float width = 0.0f;
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
    } else if (result != NULL) {
        jbyteArray rasterized = (jbyteArray)result;
        jsize len = (*env)->GetArrayLength(env, rasterized);
        if (len >= 20) {
            jbyte* raw = (*env)->GetPrimitiveArrayCritical(env, rasterized, NULL);
            if (raw != NULL) {
                const uint8_t* bytes = (const uint8_t*)raw;
                int32_t mask_w = read_i32_le(bytes + 0);
                int32_t mask_h = read_i32_le(bytes + 4);
                width = read_f32_le(bytes + 8);
                float height = read_f32_le(bytes + 12);
                int32_t mask_stride = read_i32_le(bytes + 16);

                int64_t alpha_bytes = (int64_t)mask_stride * (int64_t)mask_h;
                int64_t payload_len = (int64_t)len - 20;
                if (mask_w > 0 && mask_h > 0 && mask_stride >= mask_w && alpha_bytes > 0 && alpha_bytes <= payload_len) {
                    size_t target_size = (size_t)stride * (size_t)buf_height;
                    blend_glyph_mask_into_rgba(
                        buffer,
                        buf_width,
                        buf_height,
                        stride,
                        x,
                        y,
                        clip_x,
                        clip_y,
                        clip_w,
                        clip_h,
                        bytes + 20,
                        mask_w,
                        mask_h,
                        mask_stride,
                        color,
                        target_size
                    );
                    pthread_mutex_lock(&binding->mask_cache.lock);
                    mask_cache_put(
                        &binding->mask_cache, hash,
                        text_ptr, text_len, font_name_ptr, font_name_len,
                        font_size, bold, italic, max_width,
                        mask_w, mask_h, mask_stride, width, height, bytes + 20, alpha_bytes
                    );
                    pthread_mutex_unlock(&binding->mask_cache.lock);
                } else {
                    pthread_mutex_lock(&binding->mask_cache.lock);
                    mask_cache_put(
                        &binding->mask_cache, hash,
                        text_ptr, text_len, font_name_ptr, font_name_len,
                        font_size, bold, italic, max_width,
                        0, 0, 0, width, height, NULL, 0
                    );
                    pthread_mutex_unlock(&binding->mask_cache.lock);
                }

                (*env)->ReleasePrimitiveArrayCritical(env, rasterized, raw, JNI_ABORT);
            }
        }
    }

    if (result != NULL) {
        (*env)->DeleteLocalRef(env, result);
    }

    if (should_detach && g_vm != NULL) {
        (*g_vm)->DetachCurrentThread(g_vm);
    }

    return (jfloat)width;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    (void)reserved;
    g_vm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT jboolean JNICALL
Java_io_github_ivere27_volvoxgrid_NativeTextRendererBridge_nativeHasBuiltinTextEngine(
    JNIEnv* env,
    jclass clazz,
    jlong plugin_handle
) {
    (void)env;
    (void)clazz;
    vv_has_builtin_text_engine_fn fn = resolve_has_builtin_text_engine_fn((int64_t)plugin_handle);
    if (fn == NULL) {
        // Older plugin builds do not expose this symbol: assume built-in engine exists.
        return JNI_TRUE;
    }
    return fn() != 0 ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_io_github_ivere27_volvoxgrid_NativeTextRendererBridge_nativeRegisterTextRenderer(
    JNIEnv* env,
    jclass clazz,
    jlong plugin_handle,
    jlong grid_id,
    jobject callback
) {
    (void)clazz;
    if (callback == NULL) {
        return -1;
    }
    vv_set_text_renderer_fn fn = resolve_set_text_renderer_fn((int64_t)plugin_handle);
    if (fn == NULL) {
        return -2;
    }

    RendererBinding* binding = create_binding(env, callback);
    if (binding == NULL) {
        return -3;
    }

    int32_t rc = fn(
        (int64_t)grid_id,
        bridge_measure_text,
        bridge_render_text,
        (void*)binding
    );
    if (rc != 0) {
        free_binding(binding);
        return (jint)rc;
    }

    pthread_mutex_lock(&g_bindings_lock);
    RendererBinding* old = take_binding_for_grid_locked((int64_t)grid_id);
    put_binding_for_grid_locked((int64_t)grid_id, binding);
    pthread_mutex_unlock(&g_bindings_lock);
    free_binding(old);

    return 0;
}

JNIEXPORT jint JNICALL
Java_io_github_ivere27_volvoxgrid_NativeTextRendererBridge_nativeClearTextRenderer(
    JNIEnv* env,
    jclass clazz,
    jlong plugin_handle,
    jlong grid_id
) {
    (void)env;
    (void)clazz;
    vv_set_text_renderer_fn fn = resolve_set_text_renderer_fn((int64_t)plugin_handle);
    if (fn == NULL) {
        return -2;
    }

    int32_t rc = fn((int64_t)grid_id, NULL, NULL, NULL);

    pthread_mutex_lock(&g_bindings_lock);
    RendererBinding* old = take_binding_for_grid_locked((int64_t)grid_id);
    pthread_mutex_unlock(&g_bindings_lock);
    free_binding(old);

    return (jint)rc;
}

JNIEXPORT void JNICALL
Java_io_github_ivere27_volvoxgrid_NativeTextRendererBridge_nativeSetTextRendererCacheCap(
    JNIEnv* env,
    jclass clazz,
    jlong plugin_handle,
    jlong grid_id,
    jint cap
) {
    (void)env;
    (void)clazz;
    (void)plugin_handle;

    pthread_mutex_lock(&g_bindings_lock);
    BindingNode* node = g_bindings;
    while (node != NULL) {
        if (node->grid_id == (int64_t)grid_id) {
            pthread_mutex_lock(&node->binding->mask_cache.lock);
            mask_cache_set_capacity(&node->binding->mask_cache, (int)cap);
            pthread_mutex_unlock(&node->binding->mask_cache.lock);
            break;
        }
        node = node->next;
    }
    pthread_mutex_unlock(&g_bindings_lock);
}
