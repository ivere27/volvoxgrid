const gridOptions = {
  columnDefs: [
    { field: 'event', headerName: 'Event', width: 180 },
    {
      field: 'dateObj',
      headerName: 'Date Object',
      width: 220,
      valueFormatter: (p) => {
        if (p.value instanceof Date && !isNaN(p.value.getTime())) {
          return p.value.toISOString().split('T')[0];
        }
        return '';
      },
    },
    {
      field: 'dateStr',
      headerName: 'Date String',
      width: 220,
      valueFormatter: (p) => {
        if (typeof p.value !== 'string' || p.value.length === 0) return '';
        const d = new Date(p.value);
        return isNaN(d.getTime()) ? p.value : d.toLocaleDateString('en-US');
      },
    },
    {
      field: 'timestamp',
      headerName: 'Timestamp',
      width: 200,
      valueFormatter: (p) => {
        const ts = Number(p.value);
        if (!isFinite(ts) || ts === 0) return '';
        return new Date(ts).toISOString();
      },
    },
  ],
  rowData: [
    {
      event: 'Product Launch',
      dateObj: new Date('2026-03-15T09:00:00Z'),
      dateStr: '2026-03-15',
      timestamp: 1773756000000,
    },
    {
      event: 'Q1 Review',
      dateObj: new Date('2026-01-10T14:30:00Z'),
      dateStr: '2026-01-10T14:30:00Z',
      timestamp: 1736519400000,
    },
    {
      event: 'Conference',
      dateObj: new Date('2025-11-22T00:00:00Z'),
      dateStr: 'Nov 22, 2025',
      timestamp: 0,
    },
    {
      event: 'TBD',
      dateObj: new Date('invalid'),
      dateStr: '',
      timestamp: null,
    },
  ],
};
