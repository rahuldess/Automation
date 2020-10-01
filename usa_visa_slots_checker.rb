require 'watir'
require 'twilio-ruby'
require 'byebug'
require 'nokogiri'

begin
  # Setting chrome for heroku
  Selenium::WebDriver::Chrome.path        = "/app/.apt/usr/bin/google-chrome"
  Selenium::WebDriver::Chrome.driver_path = "/app/.chromedriver/bin/chromedriver"

  # Select the browser
  browser       = Watir::Browser.new :chrome
  twilio_client = Twilio::REST::Client.new ENV['TWILIO_ACCT'], ENV['TWILIO_TOKEN']

  # Open the URL
  browser.goto "https://ais.usvisa-info.com/en-ca/niv/users/sign_in"

  # Fill the credentials
  browser.text_field(id: 'user_email').set(ENV['LOGIN_EMAIL'])
  browser.text_field(id: 'user_password').set(ENV['LOGIN_PASSWORD'])
  browser.execute_script('$("div.icheckbox > input#policy_confirmed").click()')
  browser.input(name: 'commit').click

  # Click on Continue button
  browser.link(href: "/en-ca/niv/schedule/#{ENV['ACCOUNT_NO']}/continue_actions").click

  # Click on 'Reschedule Appointment' 
  browser.execute_script('$("#forms > ul > li:nth-child(4) > div").css("display", "block")')
  browser.link(href: "/en-ca/niv/schedule/#{ENV['ACCOUNT_NO']}/appointment").click

  # Clicking the location dropdown
  # NOTES: Switching between different cities just to trigger ajax call to fetch slots
  browser.select_list(id: "appointments_consulate_appointment_facility_id").option(text: 'Vancouver').select
  browser.select_list(id: "appointments_consulate_appointment_facility_id").option(text: 'Calgary').select
  browser.select_list(id: "appointments_consulate_appointment_facility_id").option(text: 'Vancouver').select

  # Click on 'Date of Appointment field'
  browser.input(id: "appointments_consulate_appointment_date").when_present.click

  10.times do
    available_slots = browser.execute_script('return $("table.ui-datepicker-calendar > tbody > tr > :not(td.ui-datepicker-unselectable)")')

    if available_slots.length > 0
      first_slot      = available_slots.first
      first_slot_html = first_slot.html 

      slot = Nokogiri::HTML.parse(first_slot_html).root.children.children

      first_available_month = slot.attr('data-month').value.to_i
      first_available_year  = slot.attr('data-year').value.to_i
      first_available_date  = slot.children.children.text.to_i

      if first_available_year > ENV['CURRENT_SLOT_YEAR'].to_i && 
          first_available_month > ENV['CURRENT_SLOT_MONTH'].to_i && 
          first_available_date > ENV['CURRENT_SLOT_DATE'].to_i

        return
      end
      
      # Select the first slot available
      # Select the first time slot available
      # Confirm re-schedule 
      first_slot.click
      browser.select_list(id: "appointments_consulate_appointment_time").option(index: 1).select
      browser.input(id: "appointments_submit").click

      twilio_client.messages.create(from: ENV['FROM_PHONE'], to: ENV['TO_PHONE'], body: "Slot Booked. Please check!")
      return
    else
      # Click on next button to check for next months
      browser.link(xpath: '//*[@id="ui-datepicker-div"]/div[2]/div/a').click
    end
  end

  browser.close
rescue Exception => error
  puts "--------ERROR-------"
  puts error
  puts "--------------------"
  #twilio_client.messages.create(from: ENV['FROM_PHONE'], to: ENV['DEBUG_TO_PHONE'], body: 'USA Slot check ERROR!')
end
