# encoding: utf-8
require_relative '../../../lib/varnish/lib/cartodb-varnish'
require_relative '../user'

module CartoDB
  class TablePrivacyManager
    def initialize(table)
      @table  = table
    end

    def set_public
      self.privacy = ::TableStorage::PRIVACY_PUBLIC
      set_database_permissions(grant_query)
      self
    end

    def set_private
      self.privacy = ::TableStorage::PRIVACY_PRIVATE
      set_database_permissions(revoke_query)
      self
    end

    def set_from_table_privacy(table_privacy)
      case table_privacy
        when ::TableStorage::PRIVACY_PUBLIC
          set_public
        when ::TableStorage::PRIVACY_LINK
          set_public_with_link_only
        else
          set_private
      end
    end

    def set_from(visualization)
      set_public                if visualization.public?
      set_public_with_link_only if visualization.public_with_link?
      set_private               if visualization.private? or visualization.organization?
      table.update(privacy: privacy)
      self
    end

    def propagate_to(visualization, table_privacy_changed=false)
      visualization.store_using_table({
                                        privacy_text: ::TableStorage::PRIVACY_VALUES_TO_TEXTS[privacy],
                                        map_id: visualization.map_id
                                      }, table_privacy_changed)
      self
    end

    def propagate_to_varnish
      raise 'table privacy cannot be nil' unless privacy
      # TODO: Improve this, hack because tiler checks it
      invalidate_varnish_cache
      self
    end

    private

    attr_reader   :table
    attr_accessor :privacy

    def set_public_with_link_only
      self.privacy = ::TableStorage::PRIVACY_LINK
      set_database_permissions(grant_query)
    end

    def owner
      @owner ||= User.where(id: table.user_id).first
    end

    def set_database_permissions(query)
      owner.in_database(as: :superuser).run(query)
    end

    def revoke_query
      %Q{
        REVOKE SELECT ON "#{owner.database_schema}"."#{table.name}"
        FROM #{CartoDB::PUBLIC_DB_USER}
      }
    end

    def grant_query
      %Q{
        GRANT SELECT ON "#{owner.database_schema}"."#{table.name}"
        TO #{CartoDB::PUBLIC_DB_USER};
      }
    end

    def invalidate_varnish_cache
      table.invalidate_varnish_cache(false)
    end

  end
end

