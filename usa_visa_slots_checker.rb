require 'watir'
require 'twilio-ruby'

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
  #browser.link(href: '/en-ca/niv/schedule/31865037/continue_actions').click
  #browser.link(xpath: '//*[@id="main"]/div[2]/div[3]/div[1]/div/div/div[1]/div[2]/ul/li/a').click
  browser.li(xpath: '//*[@id="main"]/div[2]/div[3]/div[1]/div/div/div[1]/div[2]/ul/li').click

  # Click on 'Reschedule Appointment' 
  browser.execute_script('$("#forms > ul > li:nth-child(4) > div").css("display", "block")')
  browser.link(href: '/en-ca/niv/schedule/31865037/appointment').click

  # Click on 'Date of Appointment field' 
  browser.input(id: "appointments_consulate_appointment_date").click

  # Each time checks 2 months 
  ENV['NO_OF_TIMES'].to_i.times do
    available_slots = browser.execute_script('return $("table.ui-datepicker-calendar > tbody > tr > :not(td.ui-datepicker-unselectable)").length')

    if available_slots > 0
      twilio_client.messages.create(from: ENV['FROM_PHONE'], to: ENV['TO_PHONE'], body: 'Slot Available. Check it quick')
      return
    end

    # Click on next button to check for next months
    browser.link(xpath: '//*[@id="ui-datepicker-div"]/div[2]/div/a').click
  end

  browser.close
rescue Exception => error
  puts "--------ERROR-------"
  puts error
  puts "--------------------"

  twilio_client.messages.create(from: ENV['FROM_PHONE'], to: ENV['DEBUG_TO_PHONE'], body: 'USA Slot check ERROR!')
end
