package io.github.ivere27.volvoxgrid.common;

/**
 * Common host/view contract for platform shells.
 */
public interface VolvoxGridHost<C extends VolvoxGridController> {
    C createController();
    void requestFrame();
    void requestFrameImmediate();
    void release();
}
