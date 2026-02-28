const columnDefs = [
  { field: 'id', headerName: 'ID' },
  { field: 'active', headerName: 'Active' },
  { field: 'meta', headerName: 'Meta' },
  {
    field: 'createdAt',
    headerName: 'Created',
    valueFormatter: (p) => {
      const dt = p.value instanceof Date ? p.value : new Date(String(p.value ?? ''));
      return Number.isNaN(dt.getTime()) ? '' : dt.toISOString();
    },
  },
];

const rowData = [
  { id: 1, active: true, meta: { region: 'NA' }, createdAt: new Date('2026-01-10T00:00:00Z') },
  { id: 2, active: false, meta: ['x', 'y'], createdAt: '2026-02-11T00:00:00Z' },
  { id: 3, active: true, meta: 42, createdAt: 'invalid' },
];
