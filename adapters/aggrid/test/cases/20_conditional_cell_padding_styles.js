const gridOptions = {
  rowHeight: 44,
  columnDefs: [
    {
      field: 'task',
      headerName: 'Task',
      width: 260,
      cellStyle: (p) => {
        const level = Number(p.data.level ?? 0);
        return {
          paddingLeft: `${10 + level * 16}px`,
          paddingTop: '10px',
          paddingBottom: '10px',
        };
      },
    },
    {
      field: 'owner',
      headerName: 'Owner',
      width: 140,
      cellStyle: {
        paddingLeft: '16px',
        paddingRight: '12px',
      },
    },
    {
      field: 'progress',
      headerName: 'Progress',
      width: 120,
      valueFormatter: (p) => `${Number(p.value ?? 0)}%`,
    },
  ],
  rowData: [
    { task: 'Program', level: 0, owner: 'Ari', progress: 70 },
    { task: 'Backend', level: 1, owner: 'Mina', progress: 78 },
    { task: 'API', level: 2, owner: 'Joon', progress: 88 },
    { task: 'Frontend', level: 1, owner: 'Luca', progress: 63 },
  ],
};
