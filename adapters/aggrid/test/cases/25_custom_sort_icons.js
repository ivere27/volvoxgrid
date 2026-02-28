const gridOptions = {
  icons: {
    sortAscending: '<span style="font-size:11px;color:#2f7d4a;">A</span>',
    sortDescending: '<span style="font-size:11px;color:#956037;">D</span>',
    sortUnSort: '<span style="font-size:11px;color:#7d8895;">U</span>',
  },
  columnDefs: [
    { field: 'athlete', headerName: 'Athlete', sortable: true },
    { field: 'country', headerName: 'Country', sortable: true },
    { field: 'gold', headerName: 'Gold', sortable: true, sort: 'desc' },
    { field: 'silver', headerName: 'Silver', sortable: true },
    { field: 'bronze', headerName: 'Bronze', sortable: true },
  ],
  rowData: [
    { athlete: 'Carla', country: 'ITA', gold: 3, silver: 0, bronze: 1 },
    { athlete: 'Alice', country: 'KOR', gold: 2, silver: 1, bronze: 0 },
    { athlete: 'Ben', country: 'USA', gold: 1, silver: 2, bronze: 2 },
  ],
};
