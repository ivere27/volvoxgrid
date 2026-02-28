const gridOptions = {
  defaultColDef: {
    sortable: true,
    resizable: true,
    minWidth: 90,
    flex: 1,
  },
  columnDefs: [
    {
      headerName: 'Identity',
      children: [
        { field: 'athlete', headerName: 'Athlete', minWidth: 130 },
        { field: 'country', headerName: 'Country' },
      ],
    },
    {
      headerName: 'Medals',
      children: [
        { field: 'gold', headerName: 'Gold', sort: 'desc' },
        { field: 'silver', headerName: 'Silver' },
        { field: 'bronze', headerName: 'Bronze' },
        {
          field: 'total',
          headerName: 'Total',
          valueGetter: (p) =>
            Number(p.data.gold ?? 0)
            + Number(p.data.silver ?? 0)
            + Number(p.data.bronze ?? 0),
        },
      ],
    },
  ],
  rowData: [
    { athlete: 'Alice', country: 'KOR', gold: 2, silver: 1, bronze: 0 },
    { athlete: 'Ben', country: 'USA', gold: 1, silver: 2, bronze: 2 },
    { athlete: 'Carla', country: 'ITA', gold: 3, silver: 0, bronze: 1 },
  ],
};
