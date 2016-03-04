FactoryGirl.define do

  factory :carto_permission, class: Carto::Permission do
    after(:build) do |permission|
      permission.owner_username = permission.owner.username
    end

  end
end
