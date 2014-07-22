class Person < Sequel::Model
  many_to_many :watchers, :class => :Person
  many_to_many :watches, :class => :Person, :right_key => :person_id, :left_key => :watcher_id

  def watched_by_name(watcher_name)
    filtered_watchers = self.watchers.select {|w| w.name == watcher_name}
    return filtered_watchers.count == 1
  end

  def watches_name(target_name)
    filtered_targets = self.watches.select {|w| w.name == target_name}
    return filtered_targets.count == 1
  end
end

class Message < Sequel::Model
  many_to_one :person

  def date
    super.iso8601
  end
end
