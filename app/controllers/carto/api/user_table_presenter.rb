class Carto::Api::UserTablePresenter

  PRIVACY_PRIVATE = 0
  PRIVACY_PUBLIC = 1
  PRIVACY_LINK = 2

  PRIVACY_VALUES_TO_TEXTS = {
      PRIVACY_PRIVATE => 'private',
      PRIVACY_PUBLIC => 'public',
      PRIVACY_LINK => 'link'
  }

  # INFO: this permission comes from user table associated visualization, which makes not much sense (at least, it should not be passed as a parameter but fetched through the association), but it's preserved (for the moment) for compatibility reasons.
  def initialize(user_table, permission)
    @user_table = user_table
    @permission = permission
  end

  def to_poro
    return {} if @user_table.nil?
    row_count_and_size = @user_table.row_count_and_size
    {
      id: @user_table.id,
      name: @user_table.name,
      permission: Carto::Api::PermissionPresenter.new(@permission).to_poro,
      geometry_types: @user_table.geometry_types,
      privacy: privacy_text(@user_table.privacy).upcase,
      updated_at: @user_table.updated_at,
      size: row_count_and_size[:size],
      row_count: row_count_and_size[:row_count]
    }
  end

  def privacy_text(privacy)
    privacy == UserTable::PRIVACY_LINK ? 'PUBLIC' : PRIVACY_VALUES_TO_TEXTS[privacy]
  end

end
