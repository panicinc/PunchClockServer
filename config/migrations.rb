# DB.drop_table :migrations
# DB.drop_table :people
# DB.drop_table :people_people

migration "create people table" do
  DB.create_table :people do
    primary_key :id
    String      :name
    DateTime    :date
    String      :status
    Integer     :version
    
    index :name, :unique => true
  end
end

migration "create people_people" do
  DB.create_table :people_people do
    primary_key :id
    Integer     :person_id
    Integer     :watcher_id
    
    index [:person_id, :watcher_id], :unique => true
  end
end

migration "add push ID" do
  DB.alter_table :people do
    add_column :push_id, :text
  end
end

migration "add beacon minor" do
  DB.alter_table :people do
    add_column :beacon_minor, :int
  end
end