<script lang="ts">
	import { currentTheme } from '$lib/store';
</script>

<div class="base {$currentTheme} mx-auto flex min-h-screen flex-col">
	<main class="flex-1 bg-[var(--background-base)] px-4 py-8 text-[var(--text-base)]">
		<div class="mx-auto max-w-4xl">
			<h1 class="mb-2 text-2xl font-bold">Haushaltsnettoeinkommen in Deutschland</h1>
			<p class="mb-6 text-sm text-[var(--text-subdued)]">
				Verteilung nach Dezilen – Näherungswerte basierend auf Destatis / EVS 2023 & DIW SOEP-Daten
			</p>

			<h2 class="mb-3 text-lg font-semibold">Dezilverteilung (je 10 % der Haushalte)</h2>
			<div class="mb-8 overflow-x-auto">
				<table class="w-full border-collapse text-sm">
					<thead>
						<tr class="border-b border-[var(--text-subdued)]">
							<th class="px-3 py-2 text-left font-semibold">Dezil</th>
							<th class="px-3 py-2 text-left font-semibold">Einkommensbereich (netto/Monat)</th>
							<th class="px-3 py-2 text-right font-semibold">Ø Einkommen</th>
							<th class="px-3 py-2 text-right font-semibold">Anteil am Gesamteinkommen</th>
						</tr>
					</thead>
					<tbody>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">1. Dezil (unterstes)</td>
							<td class="px-3 py-2">bis ca. 1.200 €</td>
							<td class="px-3 py-2 text-right">ca. 950 €</td>
							<td class="px-3 py-2 text-right">3,5 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">2. Dezil</td>
							<td class="px-3 py-2">1.200 – 1.600 €</td>
							<td class="px-3 py-2 text-right">ca. 1.400 €</td>
							<td class="px-3 py-2 text-right">5,0 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">3. Dezil</td>
							<td class="px-3 py-2">1.600 – 2.000 €</td>
							<td class="px-3 py-2 text-right">ca. 1.800 €</td>
							<td class="px-3 py-2 text-right">6,0 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">4. Dezil</td>
							<td class="px-3 py-2">2.000 – 2.400 €</td>
							<td class="px-3 py-2 text-right">ca. 2.200 €</td>
							<td class="px-3 py-2 text-right">7,0 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">5. Dezil</td>
							<td class="px-3 py-2">2.400 – 2.800 €</td>
							<td class="px-3 py-2 text-right">ca. 2.600 €</td>
							<td class="px-3 py-2 text-right">8,0 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">6. Dezil</td>
							<td class="px-3 py-2">2.800 – 3.300 €</td>
							<td class="px-3 py-2 text-right">ca. 3.050 €</td>
							<td class="px-3 py-2 text-right">9,5 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">7. Dezil</td>
							<td class="px-3 py-2">3.300 – 3.900 €</td>
							<td class="px-3 py-2 text-right">ca. 3.600 €</td>
							<td class="px-3 py-2 text-right">10,5 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">8. Dezil</td>
							<td class="px-3 py-2">3.900 – 4.700 €</td>
							<td class="px-3 py-2 text-right">ca. 4.250 €</td>
							<td class="px-3 py-2 text-right">12,0 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">9. Dezil</td>
							<td class="px-3 py-2">4.700 – 6.000 €</td>
							<td class="px-3 py-2 text-right">ca. 5.300 €</td>
							<td class="px-3 py-2 text-right">14,5 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2 font-semibold">10. Dezil (oberstes)</td>
							<td class="px-3 py-2">ab ca. 6.000 €</td>
							<td class="px-3 py-2 text-right">ca. 8.500 €</td>
							<td class="px-3 py-2 text-right">24,0 %</td>
						</tr>
					</tbody>
				</table>
			</div>

			<div class="mb-8 rounded border border-[var(--text-subdued)]/30 p-4">
				<h3 class="mb-2 font-semibold">Eckdaten (2023/2024)</h3>
				<ul class="space-y-1 text-sm">
					<li><strong>Median Haushaltsnettoeinkommen:</strong> ca. 2.600 – 2.700 €/Monat</li>
					<li><strong>Durchschnitt Haushaltsnettoeinkommen:</strong> ca. 3.500 – 3.600 €/Monat</li>
					<li><strong>Äquivalenzeinkommen (Median, Single):</strong> ca. 2.125 €/Monat (25.500 €/Jahr)</li>
				</ul>
			</div>

			<h2 class="mb-3 text-lg font-semibold">Verteilung nach Einkommensklassen</h2>
			<div class="mb-8 overflow-x-auto">
				<table class="w-full border-collapse text-sm">
					<thead>
						<tr class="border-b border-[var(--text-subdued)]">
							<th class="px-3 py-2 text-left font-semibold">Einkommensklasse (netto/Monat)</th>
							<th class="px-3 py-2 text-right font-semibold">Anteil der Haushalte</th>
						</tr>
					</thead>
					<tbody>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">unter 1.300 €</td>
							<td class="px-3 py-2 text-right">ca. 16 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">1.300 – 1.700 €</td>
							<td class="px-3 py-2 text-right">ca. 11 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">1.700 – 2.600 €</td>
							<td class="px-3 py-2 text-right">ca. 21 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">2.600 – 3.600 €</td>
							<td class="px-3 py-2 text-right">ca. 18 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">3.600 – 5.000 €</td>
							<td class="px-3 py-2 text-right">ca. 17 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">5.000 – 7.500 €</td>
							<td class="px-3 py-2 text-right">ca. 12 %</td>
						</tr>
						<tr class="border-b border-[var(--text-subdued)]/20">
							<td class="px-3 py-2">über 7.500 €</td>
							<td class="px-3 py-2 text-right">ca. 5 %</td>
						</tr>
					</tbody>
				</table>
			</div>

			<p class="text-xs text-[var(--text-subdued)]">
				Quellen: Statistisches Bundesamt (Destatis), EVS 2023, DIW Berlin SOEP. Alle Werte sind
				Näherungswerte und beziehen sich auf das ungewichtete Haushaltsnettoeinkommen.
			</p>
		</div>
	</main>
</div>
