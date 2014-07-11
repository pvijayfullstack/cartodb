REV=$(shell git rev-parse HEAD)

PENDING_SPECS = \
  spec/lib/varnish_spec.rb (#321) \
  $(NULL)

WORKING_SPECS_1 = \
  spec/models/table_spec.rb \
  spec/models/user_spec.rb \
  spec/models/layer_spec.rb \
  spec/models/map_spec.rb \
  spec/models/map/copier_spec.rb \
  $(NULL)

WORKING_SPECS_2 = \
  spec/models/visualization/*.rb \
  spec/models/named_maps_spec.rb \
  spec/models/geocoding_spec.rb \
  spec/lib/sql_parser_spec.rb \
  $(NULL)

WORKING_SPECS_3 = \
  spec/lib/sql_test_spec.rb \
  spec/lib/string_spec.rb \
  spec/lib/metrics_spec.rb \
  spec/lib/image_metadata_spec.rb \
  services/importer/spec/unit/csv_normalizer_spec.rb \
  $(NULL)

WORKING_SPECS_4 = \
  services/wms/spec/unit/wms_spec.rb \
  services/sql-api/spec/sql_api_spec.rb \
  spec/requests/admin/visualizations_spec.rb \
  spec/requests/admin/tables_spec.rb \
  $(NULL)

WORKING_SPECS_5 = \
  spec/requests/api/imports_spec.rb \
  spec/requests/api/geocodings_spec.rb \
  services/importer/spec/unit/url_translator/osm_spec.rb \
  services/importer/spec/unit/url_translator/osm2_spec.rb \
  $(NULL)

WORKING_SPECS_6 = \
  spec/requests/api/assets_spec.rb \
  spec/requests/api/user_layers_spec.rb \
  spec/requests/api/map_layers_spec.rb \
  spec/requests/api/records_spec.rb \
  $(NULL)

WORKING_SPECS_7 = \
  spec/requests/api/synchronizations_spec.rb \
  services/geocoder/spec/geocoder_spec.rb \
  spec/models/synchronization/ \
  spec/models/organization_spec.rb \
  spec/models/permission_spec.rb \
  $(NULL)

WORKING_SPECS_8 = \
  spec/requests/api/permissions_controller_spec.rb \
  spec/models/shared_entity_spec.rb \
  spec/requests/superadmin/users_spec.rb \
  spec/requests/superadmin/organizations_spec.rb \
  $(NULL)


CDB_PATH=lib/assets/javascripts/cdb

all:
	@echo "Try make check"

prepare-test-db:
	# TODO skip this if db already exists ?
	bundle exec rake cartodb:test:prepare

check-prepared:
	bundle exec rspec $(WORKING_SPECS_1)
	bundle exec rspec $(WORKING_SPECS_2)
	bundle exec rspec $(WORKING_SPECS_3)
	bundle exec rspec $(WORKING_SPECS_4)
	bundle exec rspec $(WORKING_SPECS_5)
	bundle exec rspec $(WORKING_SPECS_6)
	bundle exec rspec $(WORKING_SPECS_7)
	bundle exec rspec $(WORKING_SPECS_8)

check: prepare-test-db check-prepared
check-frontend:
	cd lib/build && grunt test

travis: check-frontend check


# update cartodb.js submodule files
update_cdb:
	cd $(CDB_PATH); make cartodb dist/cartodb.css
	cp $(CDB_PATH)/dist/cartodb.full.uncompressed.js vendor/assets/javascripts/cartodb.uncompressed.js
	cp $(CDB_PATH)/dist/cartodb.mod.torque.uncompressed.js vendor/assets/javascripts
	cp $(CDB_PATH)/dist/cartodb.css vendor/assets/stylesheets/cartodb.css


cartodbui:
	curl http://libs.cartocdn.com/cartodbui/manifest_$(REV).yml > public/assets/manifest.yml


.PHONY: develop_cdb cartodbui



