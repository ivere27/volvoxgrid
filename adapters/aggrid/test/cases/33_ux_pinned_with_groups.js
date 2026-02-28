const gridOptions = {
  columnDefs: [
    { field: 'athlete', headerName: 'Athlete', pinned: 'left', width: 140 },
    {
      headerName: 'Event Info',
      children: [
        { field: 'sport', headerName: 'Sport', width: 130 },
        { field: 'year', headerName: 'Year', width: 90 },
      ],
    },
    {
      headerName: 'Medals',
      children: [
        { field: 'gold', headerName: 'Gold', width: 80 },
        { field: 'silver', headerName: 'Silver', width: 80 },
        { field: 'bronze', headerName: 'Bronze', width: 80 },
      ],
    },
    { field: 'total', headerName: 'Total', pinned: 'right', width: 90,
      valueGetter: (p) =>
        Number(p.data.gold ?? 0) + Number(p.data.silver ?? 0) + Number(p.data.bronze ?? 0),
    },
  ],
  rowData: [
    { athlete: 'Kim Yuna', sport: 'Figure Skating', year: 2010, gold: 1, silver: 0, bronze: 0 },
    { athlete: 'Michael P.', sport: 'Swimming', year: 2008, gold: 8, silver: 0, bronze: 0 },
    { athlete: 'Usain Bolt', sport: 'Sprint', year: 2012, gold: 3, silver: 0, bronze: 0 },
    { athlete: 'Simone B.', sport: 'Gymnastics', year: 2016, gold: 4, silver: 1, bronze: 0 },
  ],
};
