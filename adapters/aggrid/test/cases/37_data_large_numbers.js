const gridOptions = {
  columnDefs: [
    { field: 'metric', headerName: 'Metric', width: 180 },
    {
      field: 'value',
      headerName: 'Raw Value',
      width: 180,
    },
    {
      field: 'value',
      headerName: 'Formatted',
      width: 200,
      valueFormatter: (p) => {
        const v = Number(p.value ?? 0);
        if (Math.abs(v) >= 1e9) return `${(v / 1e9).toFixed(2)}B`;
        if (Math.abs(v) >= 1e6) return `${(v / 1e6).toFixed(2)}M`;
        if (Math.abs(v) >= 1e3) return `${(v / 1e3).toFixed(1)}K`;
        return v.toFixed(2);
      },
    },
  ],
  rowData: [
    { metric: 'Revenue', value: 1234567890 },
    { metric: 'Users', value: 45678901 },
    { metric: 'Transactions', value: 987654 },
    { metric: 'Avg Order', value: 42.567 },
    { metric: 'Loss', value: -15230.89 },
    { metric: 'Margin %', value: 0.1823 },
  ],
};
