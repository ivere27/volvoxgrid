const gridOptions = {
  rowHeight: 48,
  columnDefs: [
    {
      field: 'style',
      headerName: 'Style',
      width: 160,
      cellStyle: (p) => ({
        paddingLeft: '12px',
        paddingTop: '10px',
        paddingBottom: '10px',
      }),
    },
    {
      field: 'sample',
      headerName: 'Sample',
      width: 200,
      cellStyle: (p) => {
        const styles = {
          solid: '2px solid #6a8fa8',
          dashed: '2px dashed #8a7b6a',
          dotted: '2px dotted #7a8e6a',
          double: '3px double #7a6a8e',
        };
        return {
          border: styles[p.data.style] || '1px solid #999',
          paddingLeft: '12px',
          paddingTop: '8px',
          paddingBottom: '8px',
        };
      },
    },
    {
      field: 'note',
      headerName: 'Note',
      width: 180,
      cellStyle: {
        paddingLeft: '10px',
      },
    },
  ],
  rowData: [
    { style: 'solid', sample: 'Solid border', note: '2px solid' },
    { style: 'dashed', sample: 'Dashed border', note: '2px dashed' },
    { style: 'dotted', sample: 'Dotted border', note: '2px dotted' },
    { style: 'double', sample: 'Double border', note: '3px double' },
  ],
};
