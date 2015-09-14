require_relative '../../lib/cartodb/stats/explore_api'
require_relative '../../lib/explore_api'

namespace :cartodb do

  namespace :explore_api do
    VISUALIZATIONS_TABLE = 'visualizations'

    PUBLIC_VISUALIZATIONS_VIEW = 'explore_api'
    CREATE_TABLE_SQL = %Q{
      CREATE TABLE #{VISUALIZATIONS_TABLE} (
        visualization_id UUID primary key,
        visualization_name text,
        visualization_description text,
        visualization_type text,
        visualization_synced boolean,
        visualization_table_names text[],
        visualization_table_rows integer,
        visualization_table_size integer,
        visualization_geometry_types text[],
        visualization_tags text[],
        visualization_bbox geometry,
        visualization_view_box geometry,
        visualization_view_box_center geometry,
        visualization_zoom integer,
        visualization_created_at timestamp with time zone,
        visualization_updated_at timestamp with time zone,
        visualization_map_id uuid,
        visualization_title text,
        visualization_likes integer,
        visualization_mapviews integer,
        user_id uuid,
        user_username text,
        user_organization_id uuid,
        user_twitter_username text,
        user_website text,
        user_avatar_url text,
        user_available_for_hire boolean,
        language regconfig default 'english'
      ) }
    CREATE_PUBLIC_VIEW = %Q{
      CREATE OR REPLACE VIEW #{PUBLIC_VISUALIZATIONS_VIEW} AS
        SELECT  visualization_id,
                visualization_name,
                visualization_description,
                visualization_type,
                visualization_table_rows,
                visualization_table_size,
                visualization_geometry_types,
                visualization_synced,
                visualization_tags,
                visualization_created_at,
                visualization_updated_at,
                visualization_map_id,
                visualization_title,
                visualization_likes,
                visualization_mapviews::numeric/(1.0 + (now()::date - visualization_created_at::date)::numeric)^2 AS popularity,
                user_id,
                user_username,
                user_organization_id,
                user_twitter_username,
                user_website,
                user_avatar_url,
                user_available_for_hire,
                language
        FROM visualizations
    }
    FULL_TEXT_SEARCHABLE_COLUMNS = %w{ visualization_name visualization_description visualization_title }
    INDEX_GEOMETRY_COLUMNS = %w{ visualization_bbox visualization_view_box }
    DROP_TABLE_SQL = %Q{ DROP TABLE IF EXISTS #{VISUALIZATIONS_TABLE} CASCADE}
    DROP_PUBLIC_VIEW_SQL = %Q{ DROP TABLE IF EXISTS #{PUBLIC_VISUALIZATIONS_VIEW} }
    MOST_RECENT_CREATED_SQL = %Q{ SELECT MAX(visualization_created_at) FROM #{VISUALIZATIONS_TABLE} }
    MOST_RECENT_UPDATED_SQL = %Q{ SELECT MAX(visualization_updated_at) FROM #{VISUALIZATIONS_TABLE} }
    BATCH_SIZE = 1000
    # TODO: "in" searches are limited to 300. To increase batch replace with date ranges
    UPDATE_BATCH_SIZE = 300
    DAYS_TO_CHECK_LIKES = 2

    desc "Creates #{VISUALIZATIONS_TABLE} at common-data user and loads the data for the very first time. This table contains an aggregated, desnormalized view of the public data at visualizations, and it's used by Explore API"
    task :setup => [:environment] do
      db_conn.run CREATE_TABLE_SQL
      db_conn.run CREATE_PUBLIC_VIEW

      update(DAYS_TO_CHECK_LIKES)

      FULL_TEXT_SEARCHABLE_COLUMNS.each { |c|
        db_conn.run "CREATE INDEX #{VISUALIZATIONS_TABLE}_#{c}_fts_idx ON #{VISUALIZATIONS_TABLE} USING gin(to_tsvector(language, #{c}))"
      }

      INDEX_GEOMETRY_COLUMNS.each { |c|
        db_conn.run "CREATE INDEX #{VISUALIZATIONS_TABLE}_#{c}_geom_idx ON #{VISUALIZATIONS_TABLE} USING GIST(#{c})"
      }

      touch_metadata
    end

    task :setup_public_view => [:environment] do
      db_conn.run CREATE_PUBLIC_VIEW
    end

    task :drop_public_view => [:environment] do
      db_conn.run DROP_PUBLIC_VIEW_SQL
    end

    desc "Deletes the #{VISUALIZATIONS_TABLE} table"
    task :drop => [:environment] do
      db_conn.run DROP_TABLE_SQL
      db_conn.run DROP_PUBLIC_VIEW_SQL
    end

    desc "Updates the data at #{VISUALIZATIONS_TABLE}"
    task :update , [:days_back_to_update] => :environment do |t, args|
      days_back_to_check = args[:days_back_to_update].nil? ? DAYS_TO_CHECK_LIKES : args[:days_back_to_update].to_i
      stats_aggregator.timing('visualizations.update.total') do
        update(days_back_to_check)
        touch_metadata
      end
    end

    desc "Updates the all visualizations meta data at #{VISUALIZATIONS_TABLE}"
    task :update_metadata => [:environment] do
      stats_aggregator.timing('visualizations.update_metadata.total') do
        update_visualizations_metadata
        touch_metadata
      end
    end

    def update_visualizations_metadata
      page = 1
      while (visualizations = CartoDB::Visualization::Collection.new.fetch(filter_metadata(page))).count > 0 do
        updates = 0
        tables_data = explore_api.get_visualizations_table_data(visualizations)
        visualizations.each do |v|
          update_visualization_metadata(v, tables_data)
          updates += 1
        end
        print "Batch size: #{visualizations.count}.\tUpdated #{updates}\n"
        page += 1
      end
    end

    def update_visualization_metadata(visualization, tables_data)
      table_data = tables_data[visualization.user_id].nil? ? {} : tables_data[visualization.user_id][visualization.name]
      db_conn.run update_mapviews_and_likes_query(visualization, table_data)
    end

    def update(days_back_to_check)
      # We add one second because we have time fields with microseconds and this leads to
      # retrieve processed data crashing due constraint issues.
      # Ie. 2015-09-03 14:12:38+00 < 2015-09-03 14:12:38.294086+00 is true
      most_recent_created_date = db_conn[MOST_RECENT_CREATED_SQL].first[:max]
      most_recent_created_date += 1 unless most_recent_created_date.nil?
      most_recent_updated_date = db_conn[MOST_RECENT_UPDATED_SQL].first[:max]
      most_recent_updated_date += 1 unless most_recent_updated_date.nil?

      stats_aggregator.timing('visualizations.update.update_existing') do
        update_existing_visualizations_at_user(days_back_to_check)
      end
      stats_aggregator.timing('visualizations.update.insert_new') do
        insert_new_visualizations_at_user(most_recent_created_date, most_recent_updated_date)
      end
    end

    def update_existing_visualizations_at_user(days_back_to_check)
      deleted_visualization_ids = []
      privated_visualization_ids = []

      puts "UPDATING"

      # Get the last 2 days liked visualizations in order to use it as trigger to update likes, mapviews, etc
      date_to_check_likes = Time.now.beginning_of_day - days_back_to_check.days
      @liked_visualizations = explore_api.visualization_likes_since(date_to_check_likes)

      # INFO: we need to check all known visualizations because they might've been deleted
      offset = 0
      while (explore_visualizations = get_explore_visualizations(offset)).length > 0

        explore_visualizations_by_visualization_id = {}
        explore_visualizations.each { |row|
          explore_visualizations_by_visualization_id[row[:visualization_id]] = row
        }
        explore_visualization_ids = explore_visualizations.map { |ev| ev[:visualization_id] }

        visualizations = CartoDB::Visualization::Collection.new.fetch({ ids: explore_visualization_ids})

        update_result = update_visualizations(visualizations, explore_visualizations_by_visualization_id, explore_visualization_ids)

        print "Batch size: #{explore_visualizations.length}.\tMatches: #{visualizations.count}.\tUpdated #{update_result[:full_updated_count]} \tMapviews and liked updates: #{update_result[:mapviews_liked_updated_count]}\n"

        deleted_visualization_ids +=  explore_visualization_ids - visualizations.collect(&:id)
        privated_visualization_ids += update_result[:privated_visualization_ids]

        offset += explore_visualizations.length
      end

      delete_visualizations(deleted_visualization_ids, privated_visualization_ids)

    end

    def get_explore_visualizations(offset)
      db_conn[%Q{ select visualization_id, visualization_updated_at from #{VISUALIZATIONS_TABLE} order by visualization_created_at asc limit #{UPDATE_BATCH_SIZE} offset #{offset} }].all
    end

    def update_visualizations(visualizations, explore_visualizations_by_visualization_id, explore_visualization_ids)
      full_updated_count = 0
      mapviews_liked_updated_count = 0
      privated_visualization_ids = []
      visualizations.each do |v|
        explore_visualization = explore_visualizations_by_visualization_id[v.id]
        # We use to_id to remove the miliseconds that could give to erroneous updates
        # http://railsware.com/blog/2014/04/01/time-comparison-in-ruby/
        if v.updated_at.to_i != explore_visualization[:visualization_updated_at].to_i
          if v.privacy != CartoDB::Visualization::Member::PRIVACY_PUBLIC
            privated_visualization_ids << v.id
          else
            # TODO: update instead of delete-insert
            db_conn.run delete_query([v.id])
            insert_visualizations(filter_valid_visualizations([v]))
            full_updated_count += 1
          end
        else
          # INFO: retrieving mapviews makes this much slower
          # We are only updating the visualizations that have received a liked since the DAYS_TO_CHECK_LIKES in the last days
          if (@liked_visualizations.include?(v.id))
            table_data = explore_api.get_visualizations_table_data([v])
            update_visualization_metadata(v, table_data)
            mapviews_liked_updated_count += 1
          end
        end
      end
      {
        full_updated_count: full_updated_count,
        mapviews_liked_updated_count: mapviews_liked_updated_count,
        privated_visualization_ids: privated_visualization_ids
      }
    end

    def delete_visualizations(deleted_visualization_ids, privated_visualization_ids)
      puts "DELETING #{deleted_visualization_ids.length} DELETED VISUALIZATIONS"
      if deleted_visualization_ids.length > 0
        db_conn.run delete_query(deleted_visualization_ids)
      end

      puts "DELETING #{privated_visualization_ids.length} PRIVATED VISUALIZATIONS"
      if privated_visualization_ids.length > 0
        db_conn.run delete_query(privated_visualization_ids)
      end
    end

    def delete_query(ids)
      %Q{ delete from #{VISUALIZATIONS_TABLE} where visualization_id in ('#{ids.join("', '")}') }
    end

    def insert_new_visualizations_at_user(most_recent_created_date, most_recent_updated_date)

      puts "INSERTING NEW CREATED"
      page = 1
      while (visualizations = CartoDB::Visualization::Collection.new.fetch(filter(page, most_recent_created_date))).count > 0 do
        insert_visualizations(filter_valid_visualizations(visualizations))
        print "Batch ##{page}. \t Insertions: #{visualizations.count}\n"
        page += 1
      end

      puts "INSERTING OLD MADE PUBLIC"
      page = 1
      while (visualizations = CartoDB::Visualization::Collection.new.fetch(filter(page, nil, most_recent_created_date))).count > 0 do
        updated_ids = visualizations.collect(&:id)

        existing_ids = db_conn[%Q{ select visualization_id from #{VISUALIZATIONS_TABLE} where visualization_id in ('#{updated_ids.join("','")}')}].all.map { |row| row[:visualization_id] }

        missing_ids = updated_ids - existing_ids

        if missing_ids.length > 0
          missing_visualizations = visualizations.select { |v| missing_ids.include?(v.id) }
          insert_visualizations(filter_valid_visualizations(missing_visualizations))
          print "Batch ##{page}. \t Insertions: #{missing_visualizations.length}\n"
        end
        page += 1
      end

    end

    def filter(page, min_created_at = nil, min_updated_at = nil)
      filter = {
        page: page,
        per_page: BATCH_SIZE,
        order: :created_at,
        order_asc_desc: :asc,
        privacy: CartoDB::Visualization::Member::PRIVACY_PUBLIC
      }
      filter['types'] = [CartoDB::Visualization::Member::TYPE_CANONICAL, CartoDB::Visualization::Member::TYPE_DERIVED]
      filter[:min_created_at] = { date: min_created_at, included: true } if min_created_at
      filter[:min_updated_at] = { date: min_updated_at, included: true } if min_updated_at
      filter
    end

    def filter_metadata(page)
      filter = {
        page: page,
        per_page: BATCH_SIZE,
        order: :user_id,
        order_asc_desc: :asc,
        privacy: CartoDB::Visualization::Member::PRIVACY_PUBLIC
      }
      filter['types'] = [CartoDB::Visualization::Member::TYPE_CANONICAL, CartoDB::Visualization::Member::TYPE_DERIVED]
      filter
    end

    def filter_valid_visualizations(visualizations)
      visualizations.select { |v| !v.user_id.nil? && !v.user.nil? }
    end

    def insert_visualizations(visualizations)
      tables_data = explore_api.get_visualizations_table_data(visualizations)
      db_conn[:visualizations].multi_insert(
        visualizations.map { |v|
          table_data = tables_data[v.user_id].blank? || tables_data[v.user_id][v.name].blank? ? {} : tables_data[v.user_id][v.name]
          insert_visualization_hash(v, table_data)
        }
      )
    end

    def insert_visualization_hash(visualization, table_data)
      v = visualization
      u = v.user
      geometry_data = explore_api.get_geometry_data(visualization)
      {
        visualization_id: v.id,
        visualization_name: v.name,
        visualization_description: v.description,
        visualization_type: v.type,
        # Synchronization method from Visualization::Relator uses empty Hash when there is no sync
        visualization_synced: !v.synchronization.is_a?(Hash),
        visualization_table_names: explore_api.get_visualization_tables(v),
        visualization_table_rows: table_data[:rows],
        visualization_table_size: table_data[:size],
        visualization_geometry_types: table_data[:geometry_types].blank? ? nil : Sequel.pg_array(table_data[:geometry_types]),
        visualization_tags: v.tags.nil? || v.tags.empty? ? nil : Sequel.pg_array(v.tags),
        visualization_created_at: v.created_at,
        visualization_updated_at: v.updated_at,
        visualization_map_id: v.map_id,
        visualization_title: v.title,
        visualization_likes: v.likes_count,
        visualization_mapviews: v.mapviews,
        visualization_bbox: v.bbox.nil? ? nil : Sequel.lit(explore_api.bbox_from_value(v.bbox)),
        visualization_view_box: geometry_data[:view_box_polygon].nil? ? nil : Sequel.lit(geometry_data[:view_box_polygon]),
        visualization_view_box_center: geometry_data[:center_geometry].nil? ? nil : Sequel.lit(geometry_data[:center_geometry]),
        visualization_zoom: geometry_data[:zoom],
        user_id: u.id,
        user_username: u.username,
        user_organization_id: u.organization_id,
        user_twitter_username: u.twitter_username,
        user_website: u.website,
        user_avatar_url: u.avatar_url,
        user_available_for_hire: u.available_for_hire
      }
    end

    def update_mapviews_and_likes_query(visualization, table_data)
      %Q{ UPDATE #{VISUALIZATIONS_TABLE} set
            visualization_mapviews = #{visualization.mapviews},
            visualization_likes = #{visualization.likes_count},
            visualization_synced = #{!visualization.is_synced?}
            #{update_tables(visualization)}
            #{update_geometry(visualization)}
            #{update_table_data(visualization.type, table_data)}
          where visualization_id = '#{visualization.id}' }
    end

    def update_tables(visualization)
      %Q{, visualization_table_names = '#{explore_api.get_visualization_tables(visualization)}'}
    end

    def update_geometry(visualization)
      geometry_data = explore_api.get_geometry_data(visualization)
      view_box_polygon = geometry_data[:view_box_polygon].nil? ? 'NULL' : geometry_data[:view_box_polygon]
      center_geometry = geometry_data[:center_geometry].nil? ? 'NULL' : geometry_data[:center_geometry]
      view_zoom = geometry_data[:zoom].nil? ? 'NULL' : geometry_data[:zoom]
      bbox_value = !visualization.bbox.nil? ? "ST_AsText('#{visualization.bbox}')" : 'NULL'
      if visualization.type == CartoDB::Visualization::Member::TYPE_DERIVED
        %Q{, visualization_bbox = #{bbox_value},
             visualization_view_box = #{view_box_polygon},
             visualization_view_box_center = #{center_geometry},
             visualization_zoom = #{view_zoom}}
      elsif !bbox_value.nil?
        %Q{, visualization_bbox = #{bbox_value}}
      else
        return
      end
    end

    def update_table_data(visualization_type, table_data)
      return if table_data.blank?
      if visualization_type == CartoDB::Visualization::Member::TYPE_CANONICAL
        %Q{, visualization_table_rows = #{table_data[:rows]},
             visualization_table_size = #{table_data[:size]},
             visualization_geometry_types = '{#{table_data[:geometry_types].join(',')}}'}
      end
    end

    def common_data_user
      username = Cartodb.config[:explore_api]['username']
      @user ||= User.where(username: username).first
    end

    def db_conn(*args)
      common_data_user.in_database(*args)
    end

    def explore_api
      @explore_api ||= ExploreAPI.new
    end

    def touch_metadata
      db_conn(as: :superuser).run(%Q{SELECT CDB_TableMetadataTouch('#{VISUALIZATIONS_TABLE}')})
    end

    def stats_aggregator
      CartoDB::Stats::ExploreAPI.instance
    end

  end

end
