import 'package:volvoxgrid/volvoxgrid_ffi.dart' as vg;

import 'types.dart';

vg.SortOrder mapSortDirection(SortDirection direction) {
  switch (direction) {
    case SortDirection.ascending:
      return vg.SortOrder.SORT_GENERIC_ASCENDING;
    case SortDirection.descending:
      return vg.SortOrder.SORT_GENERIC_DESCENDING;
  }
}
