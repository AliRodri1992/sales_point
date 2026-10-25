// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import Swal from "sweetalert2"
import "./controllers"
import { installAutomaticSelects } from "./controllers/automatic_selects"
import "./admin/dashboard"
import "./admin/sidebar"

window.Swal = Swal

installAutomaticSelects()
