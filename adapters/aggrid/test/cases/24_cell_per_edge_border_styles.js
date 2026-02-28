const gridOptions = {
  rowHeight: 42,
  columnDefs: [
    {
      field: 'phase',
      headerName: 'Phase',
      width: 180,
      cellStyle: (p) => ({
        borderLeft: '4px solid #889db6',
        borderBottom: Number(p.data.risk ?? 0) >= 7 ? '2px solid #b88989' : '1px solid #9cb1c6',
        paddingLeft: `${10 + Number(p.data.depth ?? 0) * 10}px`,
      }),
    },
    {
      field: 'owner',
      headerName: 'Owner',
      width: 150,
      cellStyle: {
        borderTop: '2px solid #a7b8ca',
        borderRight: '2px solid #a7b8ca',
        paddingLeft: '12px',
        paddingRight: '12px',
      },
    },
    {
      field: 'progress',
      headerName: 'Progress',
      width: 130,
      valueFormatter: (p) => `${Number(p.value ?? 0)}%`,
      cellStyle: (p) => ({
        borderTop: '1px solid #9cb0c5',
        borderBottom: '3px solid #8097af',
        borderRight: Number(p.value ?? 0) >= 80 ? '3px solid #6f9f87' : '3px solid #b98e78',
        paddingLeft: '12px',
      }),
    },
    {
      field: 'risk',
      headerName: 'Risk',
      width: 100,
      cellStyle: (p) => ({
        borderLeft: '2px dashed #9ab0c6',
        borderTop: '1px solid #9cb0c5',
        borderBottom: '1px solid #9cb0c5',
        paddingLeft: '10px',
        fontWeight: Number(p.value ?? 0) >= 7 ? '700' : '400',
      }),
    },
  ],
  rowData: [
    { phase: 'Program', depth: 0, owner: 'Ari', progress: 72, risk: 6 },
    { phase: 'Backend', depth: 1, owner: 'Mina', progress: 80, risk: 5 },
    { phase: 'API', depth: 2, owner: 'Joon', progress: 89, risk: 4 },
    { phase: 'Frontend', depth: 1, owner: 'Luca', progress: 64, risk: 7 },
  ],
};
