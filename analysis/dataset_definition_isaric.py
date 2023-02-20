from databuilder.ehrql import Dataset
from databuilder.tables.beta.tpp import isaric_raw, clinical_events

import codelists

dataset = Dataset()

# Select all patients with an entry in the ISARIC table.
dataset.set_population(isaric_raw.exists_for_patient())

# for column_name in isaric_raw.qm_node.schema.column_names:
#     # The conventional way to set columns on the dataset in ehrQL would be to write them out:
#     # dataset.column = isaric_raw.sort_by(isaric_raw.column).first_for_patient().column
#     # Instead, we access the column names as attributes,
#     # so we don't have to explicitly specify them,
#     # making this dataset definition much more concise.
#     # see here for all options: https://github.com/opensafely-core/databuilder/blob/dec86f9001911665e863b4ac886327f856ab4a6c/databuilder/tables/beta/tpp.py#L204
#     # this will need to be updated to add / access new columns
#     column_on_table = getattr(isaric_raw, column_name)
#     # Choose the same row for each column.
#     column_data = getattr(
#         isaric_raw.sort_by(isaric_raw.age).first_for_patient(), column_name
#     )
#     setattr(dataset, column_name, column_data)


for column_name in ["hostdat", "age", "calc_age", "sex", "corona_ieorres", "coriona_ieorres2", "coriona_ieorres3", "inflammatory_mss", "covid19_vaccine"]:
    # Instead of approach above, choose subset of variables currently of interest, treating all as a string
    column_on_table = getattr(isaric_raw, column_name)
    # Choose the same row for each column.
    column_data = getattr(
        isaric_raw.sort_by(isaric_raw.age).first_for_patient(), column_name
    )
    setattr(dataset, column_name, column_data)




# add primary care characteristics

dataset.diabetes = (
    clinical_events.take(clinical_events.ctv3_code.is_in(codelists.diabetes)) # update to snomed
    .take(clinical_events.date.is_on_or_before(dataset.hostdat)) # should be date minus 1 day
    .exists_for_patient()
)

dataset.chronic_cardiac_disease = (
    clinical_events.take(
      clinical_events.ctv3_code.is_in(codelists.chronic_cardiac_disease) & # update to snomed
      (clinical_events.date.is_on_or_before(dataset.hostdat) - days(1))
    ) 
    .exists_for_patient()
)
