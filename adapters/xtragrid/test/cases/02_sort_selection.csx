view.OptionsBehavior.Editable = true;
view.OptionsSelection.MultiSelect = true;
view.OptionsView.ShowGroupPanel = false;

view.Columns.Clear();
view.Columns.AddVisible("Id", "ID").Width = 70;
view.Columns.AddVisible("Item", "Item").Width = 240;
view.Columns.AddVisible("Qty", "Qty").Width = 90;
view.Columns.AddVisible("Amount", "Amount").Width = 130;

var table = new DataTable();
table.Columns.Add("Id", typeof(int));
table.Columns.Add("Item", typeof(string));
table.Columns.Add("Qty", typeof(int));
table.Columns.Add("Amount", typeof(double));

for (int i = 0; i < 40; i++)
{
    table.Rows.Add(i + 1, "Product " + (char)('A' + (i % 10)), 1 + (i % 9), Math.Round((i * 37.4) % 1000.0, 2));
}

grid.DataSource = table;
view.Columns["Amount"].SortOrder = ColumnSortOrder.Descending;
view.FocusedRowHandle = 1;
view.SelectRows(1, 4);
