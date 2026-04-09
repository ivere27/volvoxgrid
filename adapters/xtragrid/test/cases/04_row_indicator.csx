view.OptionsBehavior.Editable = false;
view.OptionsSelection.MultiSelect = true;
view.OptionsView.ShowGroupPanel = false;
view.OptionsView.ShowIndicator = true;

view.Columns.Clear();
view.Columns.AddVisible("Id", "ID").Width = 70;
view.Columns.AddVisible("Name", "Name").Width = 220;
view.Columns.AddVisible("Qty", "Qty").Width = 90;

var table = new DataTable();
table.Columns.Add("Id", typeof(int));
table.Columns.Add("Name", typeof(string));
table.Columns.Add("Qty", typeof(int));

for (int i = 0; i < 18; i++)
{
    table.Rows.Add(i + 1, "Row " + (i + 1), (i % 5) + 1);
}

grid.DataSource = table;
view.FocusedRowHandle = 3;
view.SelectRows(3, 6);
