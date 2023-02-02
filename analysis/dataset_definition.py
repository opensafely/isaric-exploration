from databuilder.ehrql import Dataset
from databuilder.tables.beta.tpp import isaric_raw

dataset = Dataset()

# Select all patients with an entry in the ISARIC table.
dataset.set_population(isaric_raw.exists_for_patient())

for column_name in isaric_raw.qm_node.schema.column_names:
    # The conventional way to set columns on the dataset in ehrQL would be to write them out:
    # dataset.column = isaric_raw.sort_by(isaric_raw.column).first_for_patient().column
    # Instead, we access the column names as attributes,
    # so we don't have to explicitly specify them,
    # making this dataset definition much more concise.
    column_on_table = getattr(isaric_raw, column_name)
    column_data = getattr(
        isaric_raw.sort_by(column_on_table).first_for_patient(), column_name
    )
    setattr(dataset, column_name, column_data)
