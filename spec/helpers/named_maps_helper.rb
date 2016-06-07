module NamedMapsHelper
  def bypass_named_maps
    CartoDB::Visualization::Member.any_instance.stubs(:has_named_map?).returns(false)
    Carto::NamedMaps::Api.any_instance.stubs(get: nil, create: true, update: true, delete: true)
  end
end
