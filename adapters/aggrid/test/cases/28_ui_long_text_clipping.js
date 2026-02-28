const columnDefs = [
  { field: 'id', headerName: 'ID', width: 70 },
  { field: 'title', headerName: 'Title', width: 120 },
  { field: 'description', headerName: 'Description', width: 180 },
];

const rowData = [
  {
    id: 1,
    title: 'Short',
    description: 'OK',
  },
  {
    id: 2,
    title: 'A very long title that should be clipped by the column boundary',
    description: 'This description is extremely long and will certainly overflow the available cell width causing text clipping behavior',
  },
  {
    id: 3,
    title: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    description: 'NoSpacesInThisStringToTestWrappingBehaviorWithContinuousText',
  },
];
