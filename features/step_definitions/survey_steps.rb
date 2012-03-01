include CsvSurveyOperations

Given /^I have a survey with name "([^"]*)" and questions$/ do |name, table|
  survey = Survey.create!(:name => name)
  create_questions(survey, table)
end

Given /^I have a survey with name "([^"]*)"$/ do |name|
  Survey.create!(:name => name)
end

Given /^"([^"]*)" has sections$/ do |survey_name, table|
  survey = Survey.find_by_name(survey_name)
  table.hashes.each do |sec_attrs|
    Factory(:section, sec_attrs.merge(survey: survey))
  end
end

Given /^"([^"]*)" has questions$/ do |survey_name, table|
  survey = Survey.find_by_name(survey_name)
  create_questions(survey, table)
end

Given /^"([^"]*)" created a response to the "([^"]*)" survey$/ do |email, survey_name|
  create_response(Survey.find_by_name(survey_name), email)
end

Given /^"([^"]*)" created a response to the "([^"]*)" survey with babycode "([^"]*)"( and submitted it)?$/ do |email, survey_name, babycode, submitted|
  create_response(Survey.find_by_name(survey_name), email, babycode, submitted)
end

def create_response(survey, email, babycode = 'babycode123', submitted = false)
  user = User.find_by_email(email)
  submitted_status = submitted ? Response::STATUS_SUBMITTED : Response::STATUS_UNSUBMITTED
  Response.create!(survey: survey, baby_code: babycode, user: user, hospital: user.hospital, submitted_status: submitted_status)
end

When /^I answer "([^"]*)" with "([^"]*)"$/ do |q, a|
  question = Question.find_by_question(q)
  fill_in "question_#{question.id}", :with => a
end

Then /^I should see help text "([^"]*)" for question "([^"]*)"$/ do |text, question_label|
  question = question_div(question_label)

  classes = question[:class].split(" ")
  classes.include?("warning").should be_false

  help_text = question.find(".help-block")
  help_text.text.gsub("\n", "").should eq(text)
end

Then /^I should see( fatal)? warning "([^"]*)" for question "([^"]*)"$/ do |maybe_fatal, warning, question_label|
  question = question_div(question_label)

  classes = question[:class].split(" ")
  expected_class = maybe_fatal ? 'fatalwarning' : 'warning'
  classes.include?(expected_class).should be_true, "Expected question div to have class=#{expected_class}, but found only #{classes}"

  warning_text = question.find(".help-block")
  warning_text.text.gsub("\n", "").should eq(warning)
end

Then /^I should see warnings as follows$/ do |table|
  table.hashes.each do |attrs|

    question = question_div(attrs[:question])

    classes = question[:class].split(" ")

    expected_class = attrs[:fatal] ? 'fatalwarning' : 'warning'
    classes.include?(expected_class).should be_true, "Expected question div to have class=#{expected_class}, but found only #{classes}"

    warning_text = question.find(".help-block")
    warning_text.text.gsub("\n", "").should eq(attrs[:warning])
  end
end

Then /^I should see no warnings$/ do
  page.should_not have_css(".warning")
end

Then /^"([^"]*)" should have no warning$/ do |question_label|
  question = question_div(question_label)

  classes = question[:class].split(" ")
  classes.include?("warning").should be_false
end

When /^I create a response for "([^"]*)" with baby code "([^"]*)"$/ do |survey, baby_code|
  visit path_to("the home page")
  click_link "Start New Survey Response"
  fill_in "Baby code", :with => baby_code
  select survey, :from => "Survey"
  click_button "Save"
end

def question_div(question_label)
  question = Question.find_by_question(question_label)
  find("#container_#{question.id}")
end

Given /^I answer as follows$/ do |table|
  table.hashes.each do |attrs|
    question = Question.find_by_question!(attrs["question"])
    answer_value = attrs["answer"]
    case question.question_type
      when 'Choice'
        within(question_div(question.question)) { choose(answer_value) }
      when 'Date'
        if answer_value.blank?
          y = "Year"
          m = "Month"
          d = "Day"
        else
          y, m, d = answer_value.split '/'
        end
        select y, from: "answers_#{question.id}_year"
        select m, from: "answers_#{question.id}_month"
        select d, from: "answers_#{question.id}_day"
      when 'Time'
        if answer_value.blank?
          h = "Hour"
          m = "Minute"
        else
          h, m = answer_value.split ':'
        end
        select h, from: "answers_#{question.id}_hour"
        select m, from: "answers_#{question.id}_min"
      else
        fill_in "question_#{question.id}", with: answer_value.to_s
    end
  end
end

Then /^I should see the following answers$/ do |table|
  questions_to_answer_values = table_to_questions_and_answers(table)
  questions_to_answer_values.each do |question, answer_value|
    case question.question_type
      when 'Decimal', 'Integer', 'Text'
        field = find_field("question_#{question.id}")
        field_value = field.value
      when 'Date'
        y = find("#answers_#{question.id}_year").value
        m = find("#answers_#{question.id}_month").value
        d = find("#answers_#{question.id}_day").value
        field_value = "#{y}/#{m}/#{d}"
      when 'Time'
        m = find("#answers_#{question.id}_min").value
        h = find("#answers_#{question.id}_hour").value
        field_value = "#{h}:#{m}"
      when 'Choice'
        field_value = get_checked_radio(question.question)
      else
        raise "Not Implemented"
    end
    field_value.should eq answer_value.to_s
  end
end

def table_to_questions_and_answers(table)
  table.hashes.reduce([]) do |arr, row|
    question_question = row[:question]
    answer_value = row[:answer]
    question = Question.find_by_question!(question_question)
    case question.question_type
      when 'Text', 'Choice', 'Date', 'Time'
        'no op'
      when 'Decimal'
        answer_value = answer_value.to_f
      when 'Integer'
        answer_value = answer_value.to_i
      else
        raise 'no such question type'
    end
    arr.push [question, answer_value]
    arr
  end
end

Given /^question "([^"]*)" has question options$/ do |question_name, table|
  question = Question.find_by_question(question_name)
  question.question_options.delete_all
  table.hashes.each do |qo_attrs|
    question.question_options.create!(qo_attrs)
  end
end

Then /^I should see choice question "([^"]*)" with options$/ do |question_name, table|
  options_on_page = get_choices_for_question(question_name)
  options_on_page.should eq(table.hashes)
end

Then /^the answer to "([^"]*)" should be "([^"]*)"$/ do |question_name, expected_answer|
  question = Question.find_by_question!(question_name)
  response = Response.last
  answer = response.answers.find_by_question_id(question.id)
  raise "Didn't find any answer for question '#{question_name}'" unless answer
  case question.question_type
    when 'Text'
      answer.text_answer.should eq(expected_answer)
    when 'Date'
      raise 'Not implemented'
    when 'Time'
      raise 'Not implemented'
    when 'Choice'
      answer.choice_answer.should eq(expected_answer)
    when 'Decimal'
      raise 'Not implemented'
    when 'Integer'
      answer.integer_answer.should eq(expected_answer.to_i)
    else
      raise 'no such question type'
  end
end

Then /^I should see questions$/ do |table|
  expected = table.raw.collect { |r| r[0] }
  actual = all("form .clearfix label").collect { |element| element.text }
  actual.should eq(expected)
end

def create_questions(survey, table)
  table.hashes.each do |q_attrs|
    section_num = q_attrs.delete("section")
    section_num ||= 0
    section = survey.sections.find_by_order(section_num)
    section = Factory(:section, survey: survey, order: section_num) unless section
    question = Factory(:question, q_attrs.merge(section: section))
    if question.type_choice?
      Factory(:question_option, question: question, label: "Apple", option_value: "A")
      Factory(:question_option, question: question, label: "Bike", option_value: "B")
      Factory(:question_option, question: question, label: "Cat", option_value: "C")
    end
  end
end

When /^I focus on question "(.*)"$/ do |question_question|
  question = Question.find_by_question!(question_question)
  if question.type_choice?
    first_option = question.question_options.first
    focusable_selector = "#answers_#{question.id}_#{first_option.option_value}"
  elsif question.type_date?
    focusable_selector = "#answers_#{question.id}_day"
  elsif question.type_time?
    focusable_selector = "#answers_#{question.id}_hour"
  else
    focusable_selector = "#question_#{question.id}"
  end
  page.execute_script <<-endscript
    /*
     * FIXME: THIS IS A HACK
     * There are timing issues involved with when focus and blur are called.
     * We should only have to call focus once.
     */
    jQuery('#{focusable_selector}').focus().focus();
  endscript
end

Then /^I should see the sidebar help for "([^"]*)"$/ do |question_question|
  question = Question.find_by_question!(question_question)
  page.should have_content question.description
  page.should have_content question.guide_for_use
end

And /^I should not see the sidebar help for "(.*)"$/ do |question_question|
  question = Question.find_by_question!(question_question)
  page.should_not have_content question.description
  page.should_not have_content question.guide_for_use
end

When /^I hover on question label for "(.*)"$/ do |question_question|
  question = Question.find_by_question!(question_question)
  page.execute_script <<-endscript
    jQuery('#container_#{question.id}').find('label').mouseenter();
  endscript
end

Then /^I should see the help tooltip for "(.*)"$/ do |question_question|
  question = Question.find_by_question!(question_question)
  page.should have_content question.data_domain
end

When /^I follow "([^"]*)" for section "([^"]*)"$/ do |link, section|
  section_id = Section.find_by_name(section).id
  click_link "#{link.downcase.gsub(" ", "_")}_#{section_id}"
end

Then /^I should have no answers$/ do
  Answer.count.should eq(0)
end

Then /^I should have (\d+) answers?$/ do |count|
  Answer.count.should eq(count.to_i)
end

def get_choices_for_question(question_name)
  question_div = question_div(question_name)

  labels = question_div.all("ul.inputs-list li label")
  options_on_page = []
  labels.each do |label_item|
    label_text = label_item.find("span.radio-label").text
    hint_text = label_item.find("span.help-block").text
    checked = label_item.has_selector?("input[type=radio]", :checked => true)
    options_on_page << {"label" => label_text, "hint" => hint_text, "checked" => checked.to_s}
  end
  options_on_page
end

def get_checked_radio(question_name)
  question_div = question_div(question_name)

  labels = question_div.all("ul.inputs-list li label")
  labels.each do |label_item|
    if label_item.has_selector?("input[type=radio]", :checked => true)
      return label_item.find("span.radio-label").text
    end
  end

end

Then /^I should see answers for section "([^"]*)"$/ do |section_name, expected_table|
  section = Section.find_by_name(section_name)
  actual = find("table#section_#{section.id}").all('tr').map { |row| row.all('th, td').map { |cell| cell.text.strip.gsub(/\n+/, "\n") } }
  expected_table.diff!(actual)
end

Then /^I should( not)? see a submit button on the home page for survey "([^"]*)" and baby code "([^"]*)"( with( no)? warning( "(.*)")?)?$/ do |not_see, survey, baby_code, check_warning, no_warning, _, warning_text|
  survey_link = submit_survey_link(baby_code)
  if not_see
    survey_link.should_not be
  else
    survey_link.should be
  end

  if check_warning
    warning = submit_warning_homepage(baby_code)
    if no_warning
      warning.should_not be
    else
      warning.should be
      warning.text.should eq warning_text
    end
  end
end

Then /^I should( not)? see a submit button on the response summary page for survey "([^"]*)" and baby code "([^"]*)"( with( no)? warning( "(.*)")?)?$/ do |not_see, survey, baby_code, with_warning, no_warning, _, warning_text|
  if not_see
    submit_survey_link(baby_code).should_not be
  else
    submit_survey_link(baby_code).should be
  end

  if with_warning
    warning = submit_warning_summary_page(baby_code)
    if no_warning
      warning.should_not be
    else
      warning.should be
      warning.text.should eq warning_text
    end
  end
end

Then /^I should not see the response for survey "(.*)" and baby code "(.*)" on the home page$/ do |survey_name, baby_code|
  current_path = URI.parse(current_url).path
  current_path.should eq root_path

  response = response_by_survey_name_and_baby_code!(survey_name, baby_code)

  selector = "#response_#{response.id}"
  elem = find_or_nil(selector)

  elem.should be_nil
end

When /^I submit the survey for survey "(.*)" and baby code "(.*)"$/ do |survey, baby_code|
  submit_survey_link(baby_code).click
end

Then /^I should see a confirmation message that "([^"]*)" for survey "([^"]*)" has been submitted$/ do |baby_code, survey|
  find('div.alert-message.info').text.should eq "Response for #{baby_code} to #{survey} was submitted successfully."
end

Then /^I can't view response for survey "([^"]*)" and baby code "([^"]*)"$/ do |survey, baby_code|
  response = response_by_survey_name_and_baby_code!(survey, baby_code)
  visit response_path(response)
  find("div.alert-message.error").should have_content "You are not authorized to access this page."
end

Then /^I can't edit response for survey "([^"]*)" and baby code "([^"]*)"$/ do |survey, baby_code|
  response = response_by_survey_name_and_baby_code!(survey, baby_code)
  visit edit_response_path(response)
  find("div.alert-message.error").should have_content "You are not authorized to access this page."
end

Then /^I can't review response for survey "([^"]*)" and baby code "([^"]*)"$/ do |survey, baby_code|
  response = response_by_survey_name_and_baby_code!(survey, baby_code)
  visit review_answers_response_path(response)
  find("div.alert-message.error").should have_content "You are not authorized to access this page."
end

Given /^I have the standard survey setup$/ do
  question_file = Rails.root.join 'test_data/survey', 'survey_questions.csv'
  options_file = Rails.root.join 'test_data/survey', 'survey_options.csv'
  cross_question_validations_file = Rails.root.join 'test_data/survey', 'cross_question_validations.csv'
  create_survey("MySurvey", question_file, options_file, cross_question_validations_file)
end

def submit_survey_link(baby_code)
  response = Response.find_by_baby_code!(baby_code)
  selector = %Q{form[action="#{submit_response_path response}"] > input.submit_response}
  find_or_nil(selector)
end

def submit_warning_homepage(baby_code)
  response = Response.find_by_baby_code!(baby_code)
  selector = %Q{#response_#{response.id} > td:last-child > span.warning-display.submit_warning}
  find_or_nil(selector)
end

def submit_warning_summary_page(baby_code)
  response = Response.find_by_baby_code!(baby_code)
  selector = %Q{span.warning-display.submit_warning}
  find_or_nil(selector)
end

def find_or_nil(selector)
  begin
    find selector
  rescue Capybara::ElementNotFound => e
    nil
  end
end

def response_by_survey_name_and_baby_code!(survey_name, baby_code)
  survey = Survey.find_by_name!(survey_name)
  Response.find_by_survey_id_and_baby_code!(survey, baby_code)
end
