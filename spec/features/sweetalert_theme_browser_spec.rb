# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shared SweetAlert2 presentation', type: :feature, js: true do
  before { visit new_user_session_path }

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  scenario 'renders every notification state with a readable message and manual dismissal on mobile' do
    page.driver.browser.manage.window.resize_to(320, 740)

    %w[success error warning info question].each do |state|
      page.execute_script(<<~JS, state)
        window.Swal.fire({
          icon: arguments[0], toast: true, position: 'top-end',
          title: 'El correo electrónico o la contraseña son incorrectos. Inténtalo de nuevo.',
          showConfirmButton: false, showCloseButton: true, closeButtonAriaLabel: 'Cerrar aviso'
        })
      JS

      expect(page).to have_css(".swal2-toast.swal2-icon-#{state}", text: 'Inténtalo de nuevo.')
      expect_popup_inside_viewport
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const popup = document.querySelector('.swal2-popup')
          const title = popup.querySelector('.swal2-title')
          const close = popup.querySelector('.swal2-close')
          const symbol = getComputedStyle(popup.querySelector('.swal2-icon'), '::before')
          return title.scrollWidth <= title.clientWidth && close.clientHeight >= 44 &&
            symbol.maskImage !== 'none'
        })()
      JS
      find('button[aria-label="Cerrar aviso"]').click
      expect(page).to have_no_css('.swal2-popup')
    end
  end

  scenario 'preserves input validation and keyboard submission in a dialog' do
    page.execute_script(<<~JS)
      window.Swal.fire({
        icon: 'info', title: 'Nombre del registro', text: 'Completa el dato para continuar.',
        input: 'text', inputLabel: 'Nombre', showCancelButton: true,
        confirmButtonText: 'Guardar', cancelButtonText: 'Cancelar',
        inputValidator: value => value ? undefined : 'Nombre no puede estar vacío.'
      }).then(result => { window.alertTestResult = result })
    JS

    expect(page).to have_css('.swal2-popup[role="dialog"]', text: 'Nombre del registro')
    click_button 'Guardar'
    expect(page).to have_css('.swal2-validation-message', text: 'Nombre no puede estar vacío.')
    find('.swal2-input').set('Ejemplo')
    find('.swal2-input').send_keys(:enter)
    expect(page).to have_no_css('.swal2-popup')
    expect(page.evaluate_script('window.alertTestResult.isConfirmed')).to be(true)
    expect(page.evaluate_script('window.alertTestResult.value')).to eq('Ejemplo')
  end

  scenario 'keeps long dialog text and all actions inside a narrow viewport' do
    page.driver.browser.manage.window.resize_to(320, 740)
    page.execute_script(<<~JS)
      window.Swal.fire({
        icon: 'error', title: 'No se pudieron guardar los cambios del registro.',
        text: 'Revisa la conexión e inténtalo de nuevo. El formulario conserva la información capturada.',
        showCancelButton: true, confirmButtonText: 'Reintentar', cancelButtonText: 'Cancelar'
      })
    JS

    expect(page).to have_css('.swal2-popup', text: 'No se pudieron guardar')
    expect_popup_inside_viewport
    expect(page).to have_button('Reintentar')
    click_button 'Cancelar'
    expect(page).to have_no_css('.swal2-popup')
  end

  def expect_popup_inside_viewport
    Selenium::WebDriver::Wait.new(timeout: 5, interval: 0.05).until do
      page.evaluate_script(<<~JS)
        (() => {
          const popup = document.querySelector('.swal2-popup')
          if (!popup) return false
          const box = popup.getBoundingClientRect()
          return box.left >= 0 && box.right <= innerWidth && popup.scrollWidth <= popup.clientWidth
        })()
      JS
    end
  end
end
