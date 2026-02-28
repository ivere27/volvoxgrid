const columnDefs = [
  { field: 'label', headerName: 'Label', width: 180 },
  { field: 'content', headerName: 'Content', width: 280 },
  { field: 'category', headerName: 'Category', width: 140 },
];

const rowData = [
  { label: 'Korean', content: '\uD55C\uAD6D\uC5B4 \uD14C\uC2A4\uD2B8 \uBB38\uC790\uC5F4', category: 'CJK' },
  { label: 'Japanese', content: '\u65E5\u672C\u8A9E\u30C6\u30B9\u30C8', category: 'CJK' },
  { label: 'Chinese', content: '\u4E2D\u6587\u6D4B\u8BD5\u6587\u672C', category: 'CJK' },
  { label: 'Symbols', content: '\u2714 \u2718 \u25CF \u25CB \u2605 \u2606 \u2192 \u2190', category: 'Symbol' },
  { label: 'Math', content: '\u00B1 \u00D7 \u00F7 \u2260 \u2264 \u2265 \u221E \u03C0', category: 'Math' },
  { label: 'Currency', content: '\u20A9 \u00A5 \u20AC \u00A3 $ \u20B9', category: 'Currency' },
];
