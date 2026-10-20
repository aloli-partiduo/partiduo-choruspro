# SPDX-License-Identifier: AGPL-3.0-or-later

require "../spec_helper"

# Traductions des écrans de l'extension (ADR-005 D7) : chaque route de
# `/ext/CHORUSPRO/` servie en `GET` (liste tirée du routeur de Marten),
# obtenue en fr, en et nl par un administrateur, identifiants enregistrés,
# sur un brouillon, une facture prête, une facture déposée suspendue, une
# facture mise en paiement, une facture au dépôt sans réponse et une
# facture déposée à la main. Contrôle de l'interface
# (`PartiduoUi::Translations`) : ni marqueur de traduction absente, ni clé
# brute, ni interpolation non résolue, et toute route atteinte par les liens
# des pages.

private alias S = Choruspro::SpecSupport
private alias Api = Choruspro::Api

describe "Traductions des écrans Chorus Pro (fr, en, nl)" do
  it "rend chaque écran dans chaque langue, sans clé absente, brute ni interpolation non résolue" do
    S.books
    browser = PartiduoUi::Accounts.signed_in
    S.connect
    # Écran des factures : la plus récente en tête (un brouillon, daté du
    # jour, avant les factures émises) ; seules les quatre premières fiches
    # sont suivies par les liens, les autres sont visitées ensuite.
    paid = S.issue
    Api.transmit(S.admin, paid.id).value!
    S.chorus.advance(S.chorus.deposits.keys.last, "MISE_EN_PAIEMENT")
    # Réponse perdue : réservation « sans réponse », à lever.
    uncertain = S.issue
    S.chorus.lose_answer = true
    Api.transmit(S.admin, uncertain.id)
    S.chorus.lose_answer = false
    manual = S.issue
    Api.note_manual(S.admin, manual.id, Api::ManualInput.new("CPP-12")).value!
    suspended = S.issue
    Api.transmit(S.admin, suspended.id).value!
    S.chorus.advance(S.chorus.deposits.keys.last, "SUSPENDUE", "Pièce justificative manquante")
    Api.refresh_all(S.admin).value!
    # Facture prête.
    S.issue

    explorer = PartiduoUi::Translations::Explorer.new(&.name.starts_with?("choruspro:"))
    explorer.crawl(browser, "CHORUSPRO")
    draft = S.draft(S.public_customer("Mairie de Lyon", nil, siren: "216901231"), buyer_reference: nil, order_reference: nil)
    explorer.visit(browser, "CHORUSPRO", ["/ext/CHORUSPRO/", "/ext/CHORUSPRO/invoices/#{paid.id}", "/ext/CHORUSPRO/invoices/#{draft.id}"])
    puts "\nTraductions de CHORUSPRO : #{explorer.report}"
    (explorer.failures + explorer.unreached.map { |route| "route jamais atteinte : #{route}" }).should eq([] of String)
  ensure
    # L'exploration laisse active la dernière langue demandée (nl) : les
    # exemples suivants attendent la langue par défaut.
    I18n.activate(Marten.settings.i18n.default_locale)
  end
end
