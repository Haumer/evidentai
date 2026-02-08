// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

import SubmitOnEnterController from "./submit_on_enter_controller"
application.register("submit-on-enter", SubmitOnEnterController)

import ChatScrollController from "./chat_scroll_controller"
application.register("chat-scroll", ChatScrollController)

import ArtifactSheetsController from "./artifact_sheets_controller"
application.register("artifact-sheets", ArtifactSheetsController)
