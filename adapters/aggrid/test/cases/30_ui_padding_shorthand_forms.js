const gridOptions = {
  rowHeight: 50,
  columnDefs: [
    {
      field: 'form',
      headerName: 'Padding Form',
      width: 180,
      cellStyle: {
        paddingLeft: '8px',
      },
    },
    {
      field: 'demo',
      headerName: 'Demo Cell',
      width: 220,
      cellStyle: (p) => {
        const paddingMap = {
          'single': { padding: '16px' },
          'two-value': { padding: '8px 24px' },
          'three-value': { padding: '6px 20px 14px' },
          'four-value': { padding: '4px 12px 16px 28px' },
          'individual': {
            paddingTop: '6px',
            paddingRight: '30px',
            paddingBottom: '6px',
            paddingLeft: '20px',
          },
        };
        return paddingMap[p.data.key] || {};
      },
    },
    {
      field: 'value',
      headerName: 'CSS Value',
      width: 200,
    },
  ],
  rowData: [
    { key: 'single', form: '1-value shorthand', demo: 'Content', value: 'padding: 16px' },
    { key: 'two-value', form: '2-value shorthand', demo: 'Content', value: 'padding: 8px 24px' },
    { key: 'three-value', form: '3-value shorthand', demo: 'Content', value: 'padding: 6px 20px 14px' },
    { key: 'four-value', form: '4-value shorthand', demo: 'Content', value: 'padding: 4px 12px 16px 28px' },
    { key: 'individual', form: 'Per-edge props', demo: 'Content', value: 'paddingTop/Right/Bottom/Left' },
  ],
};
