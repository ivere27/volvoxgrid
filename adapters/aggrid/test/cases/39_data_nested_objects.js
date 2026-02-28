const columnDefs = [
  { field: 'name', headerName: 'Name', width: 140 },
  { field: 'address', headerName: 'Address', width: 250 },
  { field: 'tags', headerName: 'Tags', width: 200 },
  {
    field: 'meta',
    headerName: 'Meta',
    width: 200,
    valueFormatter: (p) => {
      if (p.value == null) return '';
      if (typeof p.value === 'object') return JSON.stringify(p.value);
      return String(p.value);
    },
  },
];

const rowData = [
  {
    name: 'HQ Office',
    address: { city: 'Seoul', zip: '06164', country: 'KOR' },
    tags: ['main', 'admin'],
    meta: { floor: 12, capacity: 200 },
  },
  {
    name: 'Branch A',
    address: { city: 'Busan', zip: '48058', country: 'KOR' },
    tags: ['branch'],
    meta: { floor: 3, capacity: 50 },
  },
  {
    name: 'Remote Hub',
    address: { city: 'Incheon', zip: '21999', country: 'KOR' },
    tags: ['remote', 'satellite', 'new'],
    meta: null,
  },
];
