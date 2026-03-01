rootProject.name = "volvoxgrid-desktop"
val volvoxgridDesktopSource = providers.gradleProperty("volvoxgridDesktopSource")
    .orElse(System.getenv("VOLVOXGRID_SOURCE") ?: "local")
    .get()
    .trim()
    .lowercase()

if (volvoxgridDesktopSource == "local") {
    includeBuild("../common")
}
