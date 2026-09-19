// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import Swal from "sweetalert2"
import "./controllers"
import "./admin/dashboard"

window.Swal = Swal