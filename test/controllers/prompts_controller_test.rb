require "test_helper"

class PromptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @prompt = prompts(:one)
  end

  test "should get index" do
    get prompts_url
    assert_response :success
  end

  test "should get new" do
    get new_prompt_url
    assert_response :success
  end

  test "should create prompt" do
    assert_difference("Prompt.count") do
      post prompts_url, params: { prompt: { company_id: @prompt.company_id, created_by_id: @prompt.created_by_id, frozen_at: @prompt.frozen_at, instruction: @prompt.instruction, llm_model: @prompt.llm_model, llm_provider: @prompt.llm_provider, prompt_snapshot: @prompt.prompt_snapshot, settings: @prompt.settings, status: @prompt.status } }
    end

    assert_redirected_to prompt_url(Prompt.last)
  end

  test "should show prompt" do
    get prompt_url(@prompt)
    assert_response :success
  end

  test "should get edit" do
    get edit_prompt_url(@prompt)
    assert_response :success
  end

  test "should update prompt" do
    patch prompt_url(@prompt), params: { prompt: { company_id: @prompt.company_id, created_by_id: @prompt.created_by_id, frozen_at: @prompt.frozen_at, instruction: @prompt.instruction, llm_model: @prompt.llm_model, llm_provider: @prompt.llm_provider, prompt_snapshot: @prompt.prompt_snapshot, settings: @prompt.settings, status: @prompt.status } }
    assert_redirected_to prompt_url(@prompt)
  end

  test "should destroy prompt" do
    assert_difference("Prompt.count", -1) do
      delete prompt_url(@prompt)
    end

    assert_redirected_to prompts_url
  end
end
