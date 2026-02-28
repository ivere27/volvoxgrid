import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'types.dart';

vg.SelectionMode mapSelectionMode(SelectionMode mode) {
  switch (mode) {
    case SelectionMode.none:
      return vg.SelectionMode.SELECTION_FREE;
    case SelectionMode.single:
    case SelectionMode.multiple:
      return vg.SelectionMode.SELECTION_BY_ROW;
  }
}

vg.SelectionVisibility mapSelectionVisibility(SelectionMode mode) {
  switch (mode) {
    case SelectionMode.none:
      return vg.SelectionVisibility.SELECTION_VIS_NONE;
    case SelectionMode.single:
    case SelectionMode.multiple:
      return vg.SelectionVisibility.SELECTION_VIS_WHEN_FOCUSED;
  }
}
