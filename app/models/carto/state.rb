# encoding: UTF-8

require 'json'
require_relative './carto_json_serializer'

class Carto::State < ActiveRecord::Base
  belongs_to :visualization, class_name: Carto::Visualization
  belongs_to :user, class_name: Carto::User

  default_scope order('created_at DESC')

  serialize :json, ::Carto::CartoJsonSymbolizerSerializer

  validates :json, carto_json_symbolizer: true
  validates :visualization, :user, presence: true

  after_initialize :ensure_json

  private

  def ensure_json
    self.json ||= Hash.new
  end
end
