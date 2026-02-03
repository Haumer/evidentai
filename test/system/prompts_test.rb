require "application_system_test_case"

class PromptsTest < ApplicationSystemTestCase
  setup do
    @prompt = prompts(:one)
  end

  test "visiting the index" do
    visit prompts_url
    assert_selector "h1", text: "Prompts"
  end

  test "should create prompt" do
    visit prompts_url
    click_on "New prompt"

    fill_in "Company", with: @prompt.company_id
    fill_in "Created by", with: @prompt.created_by_id
    fill_in "Frozen at", with: @prompt.frozen_at
    fill_in "Instruction", with: @prompt.instruction
    fill_in "Llm model", with: @prompt.llm_model
    fill_in "Llm provider", with: @prompt.llm_provider
    fill_in "Prompt snapshot", with: @prompt.prompt_snapshot
    fill_in "Settings", with: @prompt.settings
    fill_in "Status", with: @prompt.status
    click_on "Create Prompt"

    assert_text "Prompt was successfully created"
    click_on "Back"
  end

  test "should update Prompt" do
    visit prompt_url(@prompt)
    click_on "Edit this prompt", match: :first

    fill_in "Company", with: @prompt.company_id
    fill_in "Created by", with: @prompt.created_by_id
    fill_in "Frozen at", with: @prompt.frozen_at
    fill_in "Instruction", with: @prompt.instruction
    fill_in "Llm model", with: @prompt.llm_model
    fill_in "Llm provider", with: @prompt.llm_provider
    fill_in "Prompt snapshot", with: @prompt.prompt_snapshot
    fill_in "Settings", with: @prompt.settings
    fill_in "Status", with: @prompt.status
    click_on "Update Prompt"

    assert_text "Prompt was successfully updated"
    click_on "Back"
  end

  test "should destroy Prompt" do
    visit prompt_url(@prompt)
    click_on "Destroy this prompt", match: :first

    assert_text "Prompt was successfully destroyed"
  end
end
