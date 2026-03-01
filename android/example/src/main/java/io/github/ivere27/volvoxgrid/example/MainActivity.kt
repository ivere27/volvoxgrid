package io.github.ivere27.volvoxgrid.example

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageButton
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import io.github.ivere27.volvoxgrid.*
import io.github.ivere27.synurang.PluginHost
import java.io.File
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/**
 * VolvoxGrid demo for Android showing three demo scenarios:
 * 1. Sales Showcase (~1000 rows) -- subtotals, merge, combos, formats
 * 2. Hierarchy Showcase (~200 rows) -- directory tree with outline levels
 * 3. Stress Test (1,000,000 rows) -- varied column types for performance
 */
class MainActivity : AppCompatActivity() {

    private lateinit var gridView: VolvoxGridView
    private lateinit var tvStatus: TextView
    private lateinit var btnSortAsc: ImageButton
    private lateinit var btnSortDesc: ImageButton
    private lateinit var btnDemoSales: Button
    private lateinit var btnDemoHierarchy: Button
    private lateinit var btnDemoStress: Button
    
    private lateinit var spRendererMode: Spinner
    private lateinit var swDebug: Switch
    private lateinit var spTextCache: Spinner
    private var rendererMode = 0 // 0=CPU, 1=GPU(Auto), 3=GPU(Vulkan), 4=GPU(GLES)
    private var litePluginLoaded = false
    private var debugOverlayEnabled = false
    private var textLayoutCacheCap = 8192
    // Keep enabled by default. VolvoxGridView now falls back automatically to
    // CPU present path if runtime surface producer switching fails on device.
    private val useGpuSurfacePath = true
    private val textCacheCapOptions = intArrayOf(8192, 4096, 1024, 256, 0)
    private val rendererModeOptions = arrayOf("CPU", "GPU (Auto)", "GPU (Vulk)", "GPU (GLES)")
    private val rendererModeValues = intArrayOf(0, 1, 3, 4)

    @Volatile private var controller: VolvoxGridController? = null
    @Volatile private var currentDemo: String = ""
    
    // Persistent state for multiple demos
    private var pluginHost: PluginHost? = null
    private val gridMap = mutableMapOf<String, Long>()
    private val controllerMap = mutableMapOf<String, VolvoxGridController>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        setContentView(R.layout.activity_main)

        gridView = findViewById(R.id.gridView)
        tvStatus = findViewById(R.id.tvStatus)
        btnSortAsc = findViewById(R.id.btnSortAsc)
        btnSortDesc = findViewById(R.id.btnSortDesc)
        btnDemoSales = findViewById(R.id.btnDemoSales)
        btnDemoHierarchy = findViewById(R.id.btnDemoHierarchy)
        btnDemoStress = findViewById(R.id.btnDemoStress)
        spRendererMode = findViewById(R.id.spRendererMode)
        swDebug = findViewById(R.id.swDebug)
        spTextCache = findViewById(R.id.spTextCache)

        val modeAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, rendererModeOptions)
        modeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spRendererMode.adapter = modeAdapter
        spRendererMode.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (litePluginLoaded && position > 0) {
                    spRendererMode.setSelection(0)
                    return
                }
                val selected = rendererModeValues[position]
                if (selected == rendererMode) return
                rendererMode = selected
                thread {
                    try {
                        controller?.setRendererMode(selected)
                        controller?.refresh()
                        runOnUiThread {
                            val viewMode = if (useGpuSurfacePath) selected else 0
                            gridView.setRendererMode(viewMode)
                            gridView.requestFrame()
                        }
                    } catch (_: Exception) {}
                }
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        val cacheLabels = textCacheCapOptions.map { it.toString() }
        val cacheAdapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            cacheLabels
        )
        cacheAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spTextCache.adapter = cacheAdapter
        spTextCache.setSelection(textCacheCapOptions.indexOf(textLayoutCacheCap).coerceAtLeast(0))
        gridView.setAndroidTextCacheSize(textLayoutCacheCap)
        spTextCache.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (position < 0 || position >= textCacheCapOptions.size) return
                val selected = textCacheCapOptions[position]
                if (selected == textLayoutCacheCap) return
                textLayoutCacheCap = selected
                thread {
                    try {
                        gridView.setAndroidTextCacheSize(selected)
                        controller?.setTextLayoutCacheCap(selected)
                        controller?.refresh()
                        gridView.requestFrame()
                    } catch (_: Exception) {}
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        // Sort handlers
        btnSortAsc.setOnClickListener { sortGrid(true) }
        btnSortDesc.setOnClickListener { sortGrid(false) }

        // Debug overlay toggle
        swDebug.setOnCheckedChangeListener { _, isChecked ->
            thread {
                try {
                    debugOverlayEnabled = isChecked
                    controller?.setDebugOverlay(isChecked)
                    controller?.refresh()
                    gridView.requestFrame()
                } catch (_: Exception) {}
            }
        }

        // Demo switch handlers
        btnDemoSales.setOnClickListener { switchDemo("sales") }
        btnDemoHierarchy.setOnClickListener { switchDemo("hierarchy") }
        btnDemoStress.setOnClickListener { switchDemo("stress") }

        setGridControlsEnabled(false)
        updateStatus("Initializing plugin...")

        // Listen for grid events
        gridView.eventListener = object : VolvoxGridView.GridEventListener {
            override fun onGridEvent(event: GridEvent) {
                when {
                    event.hasCellFocusChanging() -> {
                        val e = event.cellFocusChanging
                        updateStatus("Cell: R${e.newRow} C${e.newCol}")
                    }
                    event.hasCellFocusChanged() -> {
                        val e = event.cellFocusChanged
                        updateStatus("Cell: R${e.newRow} C${e.newCol}")
                    }
                    event.hasAfterEdit() -> {
                        val e = event.afterEdit
                        updateStatus("Edited R${e.row} C${e.col}: ${e.oldText} -> ${e.newText}")
                    }
                    event.hasAfterSort() -> {
                        updateStatus("Sorted on column ${event.afterSort.col}")
                    }
                }
            }
        }

        // Initialize plugin once, then load Sales demo
        thread { 
            if (initializePlugin()) {
                switchDemo("sales") 
            }
        }
    }

    override fun onResume() {
        super.onResume()
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    override fun onDestroy() {
        super.onDestroy()
        gridView.release()
        // Plugin host is closed by gridView.release() if it owns it, 
        // but since we shared it, we should be careful. 
        // gridView.release() calls plugin?.close(). 
        // Since we passed the host to initialize(), gridView thinks it owns it?
        // Actually PluginHost is refcounted or just a handle? 
        // It's a JNI wrapper. closing it invalidates it.
        // We should ensure gridView doesn't double-close or close prematurely if we were swapping.
        // But onDestroy means app is closing, so closing plugin is fine.
    }

    private fun initializePlugin(): Boolean {
        val libDir = applicationInfo.nativeLibraryDir
        val pluginPath = resolvePluginPath(libDir)

        if (pluginPath == null) {
            updateStatus("Plugin not found: $libDir/libvolvoxgrid_plugin.so or $libDir/libvolvoxgrid_plugin_lite.so")
            return false
        }

        try {
            pluginHost = PluginHost.load(pluginPath)
            litePluginLoaded = pluginPath.endsWith("libvolvoxgrid_plugin_lite.so")
            if (litePluginLoaded) {
                rendererMode = 0
                runOnUiThread {
                    spRendererMode.setSelection(0)
                    spRendererMode.isEnabled = false
                }
            }
            return true
        } catch (e: Exception) {
            updateStatus("Plugin load failed: ${e.message}")
            android.util.Log.e("VolvoxGridDemo", "Plugin load failed", e)
            return false
        }
    }

    private fun resolvePluginPath(libDir: String): String? {
        val candidates = listOf(
            "libvolvoxgrid_plugin.so",
            "libvolvoxgrid_plugin_lite.so",
        )
        for (name in candidates) {
            val path = "$libDir/$name"
            if (File(path).exists()) {
                return path
            }
        }
        return null
    }

    private fun switchDemo(demo: String) {
        if (demo == currentDemo && controller != null) return
        
        thread {
            try {
                val host = pluginHost ?: return@thread

                if (gridMap.containsKey(demo)) {
                    // Switch to existing grid
                    val id = gridMap[demo]!!
                    val ctrl = controllerMap[demo]!!
                    
                    runOnUiThread {
                        gridView.initialize(host, id)
                        controller = ctrl
                        currentDemo = demo
                        highlightDemoButton(demo)
                        applyDisplayToggles(ctrl)
                        ctrl.setRedraw(true)
                        ctrl.refresh() // Force repaint
                        setGridControlsEnabled(true)
                        updateStatus("Switched to $demo")
                    }
                } else {
                    // Create new grid for this demo
                    createGridForDemo(demo, host)
                }
            } catch (e: Exception) {
                updateStatus("Switch error: ${e.message}")
                android.util.Log.e("VolvoxGridDemo", "Switch failed", e)
            }
        }
    }

    private fun createGridForDemo(demo: String, host: PluginHost) {
        try {
            // Create separate grid instance in the engine
            val client = VolvoxGridServiceFfi(host)
            
            // Default size, will be resized by view
            val w = 800
            val h = 600
            val rows = 2
            val cols = 2
            val density = resources.displayMetrics.density
            val scale = if (density > 0f) density else 1f
            
            val handle = client.Create(
                CreateRequest.newBuilder()
                    .setViewportWidth(w)
                    .setViewportHeight(h)
                    .setScale(scale)
                    .setConfig(GridConfig.newBuilder()
                        .setLayout(LayoutConfig.newBuilder()
                            .setRows(rows)
                            .setCols(cols)
                            .setFixedRows(1)
                            .setFixedCols(0)
                            .build())
                        .build())
                    .build()
            )
            val id = handle.id
            
            // Attach view to this new grid
            runOnUiThread {
                gridView.initialize(host, id)
                val ctrl = gridView.createController()
                
                // Setup styling
                val style = ctrl.getGridStyle().toBuilder()
                    .setForeColor(0xFF000000.toInt())
                    .setForeColorFixed(0xFF000000.toInt())
                    .setForeColorFrozen(0xFF000000.toInt())
                    .setForeColorSel(0xFFFFFFFF.toInt())
                    .setFontName("")
                    .setFontSize(spToPx(14f).toFloat())
                    .build()
                ctrl.setGridStyle(style)
                applyDisplayToggles(ctrl)

                // Store state
                gridMap[demo] = id
                controllerMap[demo] = ctrl
                controller = ctrl
                currentDemo = demo
                
                // Populate data
                ctrl.setRedraw(false)
                loadDemoData(ctrl, demo)
                ctrl.setRedraw(true)
                ctrl.refresh()
                
                highlightDemoButton(demo)
                setGridControlsEnabled(true)
                updateStatus("Created $demo demo")
            }
        } catch (e: Exception) {
            updateStatus("Create grid failed: ${e.message}")
            android.util.Log.e("VolvoxGridDemo", "Create grid failed", e)
        }
    }

    private fun loadDemoData(ctrl: VolvoxGridController, demo: String) {
        ctrl.loadDemo(demo)
    }

    private fun applyDisplayToggles(ctrl: VolvoxGridController) {
        try {
            gridView.setAndroidTextCacheSize(textLayoutCacheCap)
            val mode = rendererMode
            ctrl.setRendererMode(mode)
            val viewMode = if (useGpuSurfacePath) mode else 0
            gridView.setRendererMode(viewMode)
            ctrl.setDebugOverlay(debugOverlayEnabled)
            ctrl.setTextLayoutCacheCap(textLayoutCacheCap)
        } catch (_: Exception) {}
    }

    private fun sortGrid(ascending: Boolean) {
        thread {
            try {
                val ctrl = controller ?: return@thread updateStatus("Grid not ready")
                val order = if (ascending)
                    SortOrder.SORT_GENERIC_ASCENDING
                else
                    SortOrder.SORT_GENERIC_DESCENDING
                ctrl.sort(order, col = ctrl.col)
                ctrl.refresh()
                gridView.requestFrame()
                updateStatus("Sorted ${if (ascending) "ascending" else "descending"}")
            } catch (e: Exception) {
                updateStatus("Sort error: ${e.message}")
            }
        }
    }

    private fun highlightDemoButton(demo: String) {
        runOnUiThread {
            btnDemoSales.alpha = if (demo == "sales") 1.0f else 0.5f
            btnDemoHierarchy.alpha = if (demo == "hierarchy") 1.0f else 0.5f
            btnDemoStress.alpha = if (demo == "stress") 1.0f else 0.5f
        }
    }

    private fun setGridControlsEnabled(enabled: Boolean) {
        runOnUiThread {
            btnSortAsc.isEnabled = enabled
            btnSortDesc.isEnabled = enabled
            btnDemoSales.isEnabled = enabled
            btnDemoHierarchy.isEnabled = enabled
            btnDemoStress.isEnabled = enabled
            spRendererMode.isEnabled = enabled && !litePluginLoaded
            swDebug.isEnabled = enabled
            spTextCache.isEnabled = enabled
        }
    }

    private fun updateStatus(msg: String) {
        runOnUiThread { tvStatus.text = msg }
    }

    private fun spToPx(sp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, sp, resources.displayMetrics
        ).roundToInt().coerceAtLeast(1)
    }
}
