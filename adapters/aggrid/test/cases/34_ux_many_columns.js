const gridOptions = {
  defaultColDef: {
    sortable: true,
    width: 110,
  },
  columnDefs: [
    { field: 'id', headerName: 'ID', width: 70 },
    { field: 'name', headerName: 'Name', width: 130 },
    { field: 'q1', headerName: 'Q1' },
    { field: 'q2', headerName: 'Q2' },
    { field: 'q3', headerName: 'Q3' },
    { field: 'q4', headerName: 'Q4' },
    { field: 'total', headerName: 'Total',
      valueGetter: (p) =>
        Number(p.data.q1 ?? 0) + Number(p.data.q2 ?? 0) +
        Number(p.data.q3 ?? 0) + Number(p.data.q4 ?? 0),
    },
    { field: 'region', headerName: 'Region' },
    { field: 'status', headerName: 'Status' },
    { field: 'note', headerName: 'Note', width: 140 },
  ],
  rowData: [
    { id: 1, name: 'Alpha', q1: 120, q2: 135, q3: 148, q4: 160, region: 'APAC', status: 'Active', note: 'On track' },
    { id: 2, name: 'Beta', q1: 98, q2: 105, q3: 112, q4: 99, region: 'EMEA', status: 'Review', note: 'Needs attention' },
    { id: 3, name: 'Gamma', q1: 200, q2: 210, q3: 195, q4: 220, region: 'NA', status: 'Active', note: 'Top performer' },
    { id: 4, name: 'Delta', q1: 75, q2: 80, q3: 88, q4: 92, region: 'LATAM', status: 'New', note: 'Ramping up' },
  ],
};
