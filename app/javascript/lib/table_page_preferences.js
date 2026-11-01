// Persist a conscious page-size change separately from a read-only table GET.
export async function saveTablePagePreference(tableKey, perPage) {
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  const response = await fetch(`/admin/table_page_preferences/${encodeURIComponent(tableKey)}`, {
    method: "PATCH",
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": token || ""
    },
    body: JSON.stringify({ per_page: perPage })
  })

  if (!response.ok) throw new Error("Could not save table page size")
}
