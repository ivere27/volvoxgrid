const gridOptions = {
  defaultColDef: {
    sortable: true,
    flex: 1,
    minWidth: 100,
  },
  columnDefs: [
    { field: 'department', headerName: 'Department' },
    { field: 'name', headerName: 'Name', sort: 'asc' },
    { field: 'salary', headerName: 'Salary', sort: 'desc' },
    { field: 'level', headerName: 'Level' },
  ],
  rowData: [
    { department: 'Eng', name: 'Alice', salary: 95000, level: 'Senior' },
    { department: 'Eng', name: 'Bob', salary: 82000, level: 'Mid' },
    { department: 'Sales', name: 'Carla', salary: 88000, level: 'Senior' },
    { department: 'Sales', name: 'David', salary: 71000, level: 'Junior' },
    { department: 'Ops', name: 'Eva', salary: 76000, level: 'Mid' },
  ],
};
