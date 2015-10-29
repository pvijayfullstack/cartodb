Sequel.migration do
  up do
    Rails::Sequel.connection.run(%{
      ALTER TABLE "visualizations" ADD COLUMN country_codes text[]
    })
  end

  down do
    alter_table :visualizations do
      drop_column :country_codes
    end
  end
end
