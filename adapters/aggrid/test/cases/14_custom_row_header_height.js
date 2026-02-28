const gridOptions = {
  fontSize: 16,
  rowHeight: 52,
  headerHeight: 56,
  columnDefs: [
    { field: 'name', headerName: 'Name' },
    { field: 'role', headerName: 'Role' },
    { field: 'office', headerName: 'Office' },
  ],
  rowData: [
    { name: 'Alice', role: 'Engineer', office: 'Seoul' },
    { name: 'Bob', role: 'PM', office: 'Busan' },
    { name: 'Chloe', role: 'Designer', office: 'Incheon' },
  ],
};
