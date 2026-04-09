view.OptionsBehavior.Editable = true;
view.OptionsSelection.MultiSelect = true;
view.OptionsView.ShowGroupPanel = false;

view.Columns.Clear();
view.Columns.AddVisible("Id", "ID").Width = 80;
view.Columns.AddVisible("Task", "Task").Width = 260;
view.Columns.AddVisible("Owner", "Owner").Width = 160;
view.Columns.AddVisible("Done", "Done").Width = 90;

var table = new DataTable();
table.Columns.Add("Id", typeof(int));
table.Columns.Add("Task", typeof(string));
table.Columns.Add("Owner", typeof(string));
table.Columns.Add("Done", typeof(bool));

for (int i = 0; i < 18; i++)
{
    table.Rows.Add(i + 1, "Task " + (i + 1), "Team " + ((i % 4) + 1), (i % 3) == 0);
}

grid.DataSource = table;
view.FocusedRowHandle = 5;
view.SetRowCellValue(5, "Task", "Task 6 (edited)");
view.SetRowCellValue(5, "Done", true);
view.PostEditor();
view.UpdateCurrentRow();
view.RefreshData();
