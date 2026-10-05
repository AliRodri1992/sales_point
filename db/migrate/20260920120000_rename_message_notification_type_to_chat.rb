class RenameMessageNotificationTypeToChat < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE noticed_notifications
      SET type = 'ChatNotification::Notification'
      WHERE type = 'MessageNotification::Notification'
    SQL

    execute <<~SQL.squish
      UPDATE noticed_events
      SET type = 'ChatNotification'
      WHERE type = 'MessageNotification'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE noticed_notifications
      SET type = 'MessageNotification::Notification'
      WHERE type = 'ChatNotification::Notification'
    SQL

    execute <<~SQL.squish
      UPDATE noticed_events
      SET type = 'MessageNotification'
      WHERE type = 'ChatNotification'
    SQL
  end
end
