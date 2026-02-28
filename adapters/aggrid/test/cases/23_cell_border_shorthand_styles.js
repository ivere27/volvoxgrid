const gridOptions = {
  rowHeight: 44,
  defaultColDef: {
    width: 160,
  },
  columnDefs: [
    {
      field: 'task',
      headerName: 'Task',
      width: 220,
      cellStyle: (p) => ({
        border: '2px solid #8ea4bd',
        borderRadius: '4px',
        paddingLeft: `${12 + Number(p.data.level ?? 0) * 12}px`,
        paddingTop: '8px',
        paddingBottom: '8px',
      }),
    },
    {
      field: 'owner',
      headerName: 'Owner',
      cellStyle: {
        border: '1px dashed #9db0c5',
        paddingLeft: '14px',
        paddingRight: '12px',
      },
    },
    {
      field: 'status',
      headerName: 'Status',
      cellStyle: (p) => ({
        border: Number(p.value) >= 80 ? '2px solid #6f9f87' : '2px solid #c1a17f',
        paddingLeft: '12px',
      }),
      valueFormatter: (p) => `${Number(p.value ?? 0)}%`,
    },
  ],
  rowData: [
    { task: 'Program', level: 0, owner: 'Ari', status: 70 },
    { task: 'Backend', level: 1, owner: 'Mina', status: 78 },
    { task: 'API', level: 2, owner: 'Joon', status: 88 },
    { task: 'Frontend', level: 1, owner: 'Luca', status: 63 },
  ],
};
