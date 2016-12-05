# encoding: UTF-8

require 'json'
require_relative './carto_json_serializer'

class Carto::State < ActiveRecord::Base
  belongs_to :visualization, class_name: Carto::Visualization

  default_scope order('created_at DESC')

  serialize :json, ::Carto::CartoJsonSymbolizerSerializer

  validates :json, carto_json_symbolizer: true
  validates :visualization, presence: true

  after_initialize :ensure_json

  def self.columns
    super.reject { |c| c.name == 'user_id' }
  end

  private

  def ensure_json
    self.json ||= Hash.new
  end
end
