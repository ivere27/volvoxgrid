package io.github.ivere27.volvoxgrid.example

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.PopupMenu
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
    private lateinit var btnOverflowMenu: ImageButton
    private lateinit var btnDemoSales: Button
    private lateinit var btnDemoHierarchy: Button
    private lateinit var btnDemoStress: Button
    
    private lateinit var spRendererMode: Spinner
    private lateinit var swDebug: Switch
    private lateinit var spTextCache: Spinner
    private var rendererMode = 0 // 0=AUTO, 1=CPU, 2=GPU, 3=GPU(Vulkan), 4=GPU(GLES)
    private var litePluginLoaded = false
    private var debugOverlayEnabled = false
    private var scrollBlitEnabled = false
    private var editEnabled = false
    private var textLayoutCacheCap = 8192
    // Keep enabled by default. VolvoxGridView now falls back automatically to
    // CPU present path if runtime surface producer switching fails on device.
    private val useGpuSurfacePath = true
    private val textCacheCapOptions = intArrayOf(8192, 4096, 1024, 256, 0)
    private val rendererModeOptions = arrayOf("AUTO", "CPU", "GPU", "GPU (Vulk)", "GPU (GLES)")
    private val rendererModeValues = intArrayOf(0, 1, 2, 3, 4)
    private val renderLayerNames = arrayOf(
        "Overlay Bands",
        "Indicators",
        "Backgrounds",
        "Progress Bars",
        "Grid Lines",
        "Header Marks",
        "Background Image",
        "Cell Borders",
        "Cell Text",
        "Cell Pictures",
        "Sort Glyphs",
        "Col Drag Marker",
        "Checkboxes",
        "Dropdown Buttons",
        "Selection",
        "Hover Highlight",
        "Edit Highlights",
        "Focus Rect",
        "Fill Handle",
        "Outline",
        "Frozen Borders",
        "Active Editor",
        "Active Dropdown",
        "Scroll Bars",
        "Fast Scroll",
        "Debug Overlay",
    )

    @Volatile private var controller: VolvoxGridController? = null
    @Volatile private var currentDemo: String = ""
    private var renderLayerMask = -1L
    
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
        btnOverflowMenu = findViewById(R.id.btnOverflowMenu)
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

        btnOverflowMenu.setOnClickListener { showGridActionsMenu(it) }

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
        gridView.contextMenuRequestListener = object : VolvoxGridView.ContextMenuRequestListener {
            override fun onContextMenuRequest(request: VolvoxGridView.ContextMenuRequest) {
                showGridDebugContextMenu(request)
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
            
            val response = client.Create(
                CreateRequest.newBuilder()
                    .setViewportWidth(w)
                    .setViewportHeight(h)
                    .setScale(scale)
                    .setConfig(GridConfig.newBuilder()
                        .setLayout(LayoutConfig.newBuilder()
                            .setRows(rows)
                            .setCols(cols)
                            .build())
                        .setRendering(RenderConfig.newBuilder()
                            .setFramePacingMode(FramePacingMode.FRAME_PACING_MODE_PLATFORM)
                            .setScrollBlit(scrollBlitEnabled)
                            .build())
                        .setIndicators(IndicatorsConfig.newBuilder()
                            .setRowStart(RowIndicatorConfig.newBuilder()
                                .setVisible(false)
                                .setWidth(35)
                                .setModeBits(
                                    RowIndicatorMode.ROW_INDICATOR_CURRENT.number or
                                        RowIndicatorMode.ROW_INDICATOR_SELECTION.number
                                )
                                .build())
                            .setColTop(ColIndicatorConfig.newBuilder()
                                .setVisible(true)
                                .setBandRows(1)
                                .setModeBits(
                                    ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT.number or
                                        ColIndicatorCellMode.COL_INDICATOR_CELL_SORT_GLYPH.number
                                )
                                .build())
                            .build())
                        .build())
                    .build()
            )
            val id = response.handle.id
            
            // Attach view to this new grid
            runOnUiThread {
                gridView.initialize(host, id)
                val ctrl = gridView.createController()
                
                ctrl.setColumnCaption(0, "Name")
                ctrl.setColumnCaption(1, "Price")
                ctrl.setColumnCaption(2, "Qty")
                ctrl.setCellText(0, 0, "Widget A")
                ctrl.setCellText(0, 1, "29.99")
                ctrl.setCellText(0, 2, "150")

                // Setup styling
                val style = ctrl.getGridStyle().toBuilder()
                    .setForeground(0xFF000000.toInt())
                    .setFixed(RegionStyle.newBuilder().setForeground(0xFF000000.toInt()).build())
                    .setFrozen(RegionStyle.newBuilder().setForeground(0xFF000000.toInt()).build())
                    .setFont(
                        Font.newBuilder()
                            .setFamily("")
                            .setSize(spToPx(14f).toFloat())
                            .build()
                    )
                    .build()
                ctrl.setGridStyle(style)
                ctrl.setSelectionStyle(
                    HighlightStyle.newBuilder()
                        .setForeground(0xFFFFFFFF.toInt())
                        .build()
                )
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
        if (demo == "sales") {
            SalesJsonDemo.load(ctrl)
        } else if (demo == "hierarchy") {
            HierarchyJsonDemo.load(ctrl)
        } else {
            ctrl.loadDemo(demo)
        }
        ctrl.setEditable(editEnabled)
    }

    private fun applyDisplayToggles(ctrl: VolvoxGridController) {
        try {
            gridView.setAndroidTextCacheSize(textLayoutCacheCap)
            val mode = rendererMode
            ctrl.setRendererMode(mode)
            val viewMode = if (useGpuSurfacePath) mode else 0
            gridView.setRendererMode(viewMode)
            ctrl.setDebugOverlay(debugOverlayEnabled)
            ctrl.setScrollBlit(scrollBlitEnabled)
            ctrl.setEditable(editEnabled)
            ctrl.setTextLayoutCacheCap(textLayoutCacheCap)
            ctrl.setRenderLayerMask(renderLayerMask)
        } catch (_: Exception) {}
    }

    private fun showGridActionsMenu(anchor: View) {
        PopupMenu(this, anchor).apply {
            menuInflater.inflate(R.menu.grid_actions_menu, menu)
            menu.findItem(R.id.action_scroll_blit)?.isChecked = scrollBlitEnabled
            menu.findItem(R.id.action_edit)?.isChecked = editEnabled
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    R.id.action_sort_ascending -> {
                        sortGrid(true)
                        true
                    }
                    R.id.action_sort_descending -> {
                        sortGrid(false)
                        true
                    }
                    R.id.action_scroll_blit -> {
                        val nextValue = !scrollBlitEnabled
                        scrollBlitEnabled = nextValue
                        item.isChecked = nextValue
                        thread {
                            try {
                                controllerMap.values.forEach { it.setScrollBlit(nextValue) }
                                controller?.refresh()
                                gridView.requestFrame()
                                updateStatus(
                                    if (nextValue) {
                                        "Scroll blit enabled"
                                    } else {
                                        "Scroll blit disabled"
                                    }
                                )
                            } catch (e: Exception) {
                                updateStatus("Scroll blit toggle failed: ${e.message}")
                                android.util.Log.e("VolvoxGridDemo", "Scroll blit toggle failed", e)
                            }
                        }
                        true
                    }
                    R.id.action_edit -> {
                        val nextValue = !editEnabled
                        editEnabled = nextValue
                        item.isChecked = nextValue
                        thread {
                            try {
                                controllerMap.values.forEach { it.setEditable(nextValue) }
                                controller?.refresh()
                                gridView.requestFrame()
                                updateStatus(
                                    if (nextValue) {
                                        "Editing enabled"
                                    } else {
                                        "Editing disabled"
                                    }
                                )
                            } catch (e: Exception) {
                                updateStatus("Edit toggle failed: ${e.message}")
                                android.util.Log.e("VolvoxGridDemo", "Edit toggle failed", e)
                            }
                        }
                        true
                    }
                    R.id.action_layer_selection -> {
                        showLayerSelectionDialog()
                        true
                    }
                    else -> false
                }
            }
            show()
        }
    }

    private fun showLayerSelectionDialog() {
        var draftMask = renderLayerMask
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padding = dpToPx(12f)
            setPadding(padding, 0, padding, 0)
        }
        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        val listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val scrollView = ScrollView(this).apply {
            addView(listLayout)
        }
        val checkBoxes = renderLayerNames.mapIndexed { index, label ->
            CheckBox(this).apply {
                text = label
                isChecked = draftMask and (1L shl index) != 0L
                setOnCheckedChangeListener { _, isChecked ->
                    val bit = 1L shl index
                    draftMask = if (isChecked) {
                        draftMask or bit
                    } else {
                        draftMask and bit.inv()
                    }
                }
            }.also { listLayout.addView(it) }
        }
        fun updateChecks(mask: Long) {
            draftMask = mask
            checkBoxes.forEachIndexed { index, checkBox ->
                val checked = mask and (1L shl index) != 0L
                if (checkBox.isChecked != checked) {
                    checkBox.isChecked = checked
                }
            }
        }
        actionsRow.addView(Button(this).apply {
            text = "All"
            setOnClickListener { updateChecks(-1L) }
        })
        actionsRow.addView(Button(this).apply {
            text = "None"
            setOnClickListener { updateChecks(0L) }
        })
        content.addView(actionsRow)
        content.addView(
            scrollView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(360f)
            )
        )
        AlertDialog.Builder(this)
            .setTitle("Layer Selection")
            .setView(content)
            .setPositiveButton("Apply") { _, _ ->
                if (draftMask == renderLayerMask) return@setPositiveButton
                renderLayerMask = draftMask
                thread {
                    try {
                        val ctrl = controller ?: return@thread
                        ctrl.setRenderLayerMask(draftMask)
                        ctrl.refresh()
                        gridView.requestFrame()
                        updateStatus("Updated layer selection")
                    } catch (e: Exception) {
                        updateStatus("Layer selection error: ${e.message}")
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun sortGrid(ascending: Boolean) {
        thread {
            try {
                val ctrl = controller ?: return@thread updateStatus("Grid not ready")
                val order = if (ascending)
                    SortOrder.SORT_ASCENDING
                else
                    SortOrder.SORT_DESCENDING
                ctrl.sort(order, col = ctrl.cursorCol())
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
            btnOverflowMenu.isEnabled = enabled
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

    private fun showGridDebugContextMenu(request: VolvoxGridView.ContextMenuRequest) {
        val ctrl = controller ?: return
        val row = request.row
        val col = request.col
        if (row < 0 || col < 0) {
            return
        }

        val anchor = View(this)
        anchor.layoutParams = FrameLayout.LayoutParams(1, 1).apply {
            leftMargin = request.localX.toInt()
            topMargin = request.localY.toInt()
        }
        gridView.addView(anchor)

        val popup = PopupMenu(this, anchor)
        popup.setOnDismissListener { gridView.removeView(anchor) }
        val menu = popup.menu
        val rowLabel = row + 1

        menu.add("Pin Row $rowLabel to Top").setOnMenuItemClickListener {
            ctrl.pinRow(row, PinPosition.PIN_TOP)
            gridView.requestFrame()
            true
        }
        menu.add("Pin Row $rowLabel to Bottom").setOnMenuItemClickListener {
            ctrl.pinRow(row, PinPosition.PIN_BOTTOM)
            gridView.requestFrame()
            true
        }
        menu.add("Unpin Row $rowLabel").setOnMenuItemClickListener {
            ctrl.pinRow(row, PinPosition.PIN_NONE)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Row $rowLabel to Top").setOnMenuItemClickListener {
            ctrl.setRowSticky(row, StickyEdge.STICKY_TOP)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Row $rowLabel to Bottom").setOnMenuItemClickListener {
            ctrl.setRowSticky(row, StickyEdge.STICKY_BOTTOM)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Row $rowLabel Both").setOnMenuItemClickListener {
            ctrl.setRowSticky(row, StickyEdge.STICKY_BOTH)
            gridView.requestFrame()
            true
        }
        menu.add("Unsticky Row $rowLabel").setOnMenuItemClickListener {
            ctrl.setRowSticky(row, StickyEdge.STICKY_NONE)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Col $col to Left").setOnMenuItemClickListener {
            ctrl.setColSticky(col, StickyEdge.STICKY_LEFT)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Col $col to Right").setOnMenuItemClickListener {
            ctrl.setColSticky(col, StickyEdge.STICKY_RIGHT)
            gridView.requestFrame()
            true
        }
        menu.add("Sticky Col $col Both").setOnMenuItemClickListener {
            ctrl.setColSticky(col, StickyEdge.STICKY_BOTH)
            gridView.requestFrame()
            true
        }
        menu.add("Unsticky Col $col").setOnMenuItemClickListener {
            ctrl.setColSticky(col, StickyEdge.STICKY_NONE)
            gridView.requestFrame()
            true
        }
        menu.add("Copy").setOnMenuItemClickListener {
            val resp = ctrl.copy()
            val clipboard = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("grid", resp.text))
            true
        }

        popup.show()
    }

    private fun spToPx(sp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, sp, resources.displayMetrics
        ).roundToInt().coerceAtLeast(1)
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp, resources.displayMetrics
        ).roundToInt().coerceAtLeast(1)
    }
}
