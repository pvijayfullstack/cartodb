Sequel.migration do
  up do

    create = Rails::Sequel.connection.fetch(%Q{
      SELECT * FROM pg_indexes WHERE indexname='tmp_user_tables_map_id' and schemaname='public'
    }).count == 0
    if create
      Rails::Sequel.connection.run(%Q{
        CREATE INDEX user_tables_map_id_idx ON user_tables (map_id)
      })
    else
      Rails::Sequel.connection.run(%Q{
        ALTER INDEX tmp_user_tables_map_id RENAME TO user_tables_map_id_idx
      })
    end

    create = Rails::Sequel.connection.fetch(%Q{
      SELECT * FROM pg_indexes WHERE indexname='tmp_visualizations_map_id' and schemaname='public'
    }).count == 0
    if create
      Rails::Sequel.connection.run(%Q{
        CREATE INDEX visualizations_map_id_idx ON visualizations (map_id)
      })
    else
      Rails::Sequel.connection.run(%Q{
        ALTER INDEX tmp_visualizations_map_id RENAME TO visualizations_map_id_idx
      })
    end

    Rails::Sequel.connection.run(%Q{
      CREATE INDEX visualizations_user_id_locked_idx ON visualizations (user_id, locked)
    })

    Rails::Sequel.connection.run(%Q{
      CREATE INDEX maps_user_id_idx ON maps (user_id)
    })

    create = Rails::Sequel.connection.fetch(%Q{
      SELECT * FROM pg_indexes WHERE indexname='tmp_layers_maps_layer_id_map_id' and schemaname='public'
    }).count == 0
    if create
      Rails::Sequel.connection.run(%Q{
        CREATE INDEX layers_maps_layer_id_map_id_idx ON layers_maps (layer_id, map_id)
      })
    else
      Rails::Sequel.connection.run(%Q{
        ALTER INDEX tmp_layers_maps_layer_id_map_id RENAME TO layers_maps_layer_id_map_id_idx
      })
    end

    Rails::Sequel.connection.run(%Q{
      CREATE INDEX permissions_entity_id_idx ON permissions (entity_id)
    })

    Rails::Sequel.connection.run(%Q{
      CREATE INDEX shared_entities_recipient_id_idx ON shared_entities (recipient_id)
    })

    # We had visualization_id set as text
    Rails::Sequel.connection.run(%Q{
      ALTER TABLE overlays
      ALTER COLUMN visualization_id TYPE uuid USING visualization_id::uuid;
    })
  end

  down do
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS user_tables_map_id_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS visualizations_map_id_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS visualizations_user_id_locked_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS maps_user_id_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS layers_maps_layer_id_map_id_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS permissions_entity_id_idx
    })
    Rails::Sequel.connection.run(%Q{
      DROP INDEX IF EXISTS shared_entities_recipient_id_idx
    })

    Rails::Sequel.connection.run(%Q{
      ALTER TABLE overlays
      ALTER COLUMN visualization_id TYPE text USING visualization_id::text;
    })

  end

end
