# 1 1 1 * * /usr/bin/gitlab-rails runner /opt/extend_expiring_tokens.rb
date_range = 12.month
new_expires_at = 12.months.from_now

total_updated = PersonalAccessToken
.not_revoked
.where(expires_at: Date.today .. Date.today + date_range)
.update_all(expires_at: new_expires_at.to_date)

puts "Updated #{total_updated} tokens with new expiry date #{new_expires_at}"
