const columnDefs = [
  { field: 'task', headerName: 'Task', width: 200 },
  { field: 'done', headerName: 'Done', width: 100 },
  { field: 'archived', headerName: 'Archived', width: 110 },
  { field: 'priority', headerName: 'Priority', width: 110 },
];

const rowData = [
  { task: 'Design review', done: true, archived: false, priority: 'High' },
  { task: 'Write tests', done: false, archived: false, priority: 'Medium' },
  { task: 'Deploy v2', done: true, archived: true, priority: 'Low' },
  { task: 'Bug triage', done: false, archived: false, priority: 'High' },
];
