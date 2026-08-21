-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — R0 respiratory source map seed
-- SOURCE -> VERSION -> SECTION -> CHAPTER -> CHUNK + EXTRACTION_JOB
-- GENERATED FILE — do not edit by hand. Regenerate with:
--   python knowledge-compiler/build_respiratory_sources.py <kumar.pdf> <baby_nelson.pdf> <out>
-- Page convention: all page columns are PRINTED book pages (pdf_index - offset).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- source
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source (source_id, source_name, edition, year, source_type, authority_scope, amexan_role, description, publisher, language_code, status) VALUES
   ('KUMAR_CLARK_CM', 'Kumar & Clark''s Clinical Medicine', 10, 2017, 'textbook', 'internal medicine', 'INTERPRET + MANAGE', 'Adult internal medicine textbook; respiratory disease chapter (28) forms the adult overlay of the respiratory vertical slice.', 'Elsevier', 'en', 'ACTIVE_FOUNDATION')
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_version
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_version (version_id, source_id, edition, publication_year, language, supersedes, effective_from, status, pdf_page_offset, page_count, file_path) VALUES
   ('KUMAR_CLARK_10_2017', 'KUMAR_CLARK_CM', 10, 2017, 'English', NULL, '2017-01-01', 'ACTIVE', 18, 1508, 'C:\Users\Administrator\Desktop\UPLOADS\Kumar_and_Clark_s_Clinical_Medicine10th_Edition.pdf')
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_section
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_section (section_id, source_version_id, section_no, section_name, amexan_layer, sort_order) VALUES
   ('KC-S1', 'KUMAR_CLARK_10_2017', 1, 'Respiratory system', 'SYSTEM', 1)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_chapter
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_chapter (chapter_id, source_version_id, section_id, chapter_no, chapter_name, start_page, end_page, amexan_role, amexan_context, amexan_system, sort_order) VALUES
   ('KC-C28', 'KUMAR_CLARK_10_2017', 'KC-S1', 28, 'Respiratory disease', 927, 999, 'INTERPRET + MANAGE', NULL, 'RESPIRATORY', 1)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_chunk  (page-anchored raw text, printed page numbers)
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_chunk (id, source_version_id, chapter_id, page_number, pdf_page_index, chunk_index, chunk_text, char_count) VALUES
   ('d133e703-46c8-5a26-a05b-0bd6c507b385', 'KUMAR_CLARK_10_2017', 'KC-C28', 927, 945, 0, '927
 CLINICAL SKILLS FOR RESPIRATORY MEDICINE
History
The following features of the medical history are especially relevant 
in respiratory disease:
 • Respiratory symptoms: cough, sputum production, breathless­
ness, chest pain, haemoptysis, wheeze. Specify acuity of onset, 
change over time, change in symptoms with location.
 • Systemic symptoms: weight loss, malaise, night sweats.
 • Occupational exposure: all previous occupations, with a spe­
cific focus on exposure to asbestos, to organic materials such as 
hay, mushrooms or cotton, or to animals. Establish any relation­
ship of symptoms to work.
 • Smoking: smoking history (duration of smoking and number 
of cigarettes smoked per day), and also attempts made to give 
up, including use of nicotine replacement substances such as 
e-­cigarettes.
 • Recreational drug use: especially smoked cannabis.
 • Family history: respiratory conditions such as emphysema, 
bronchiectasis or cystic fibrosis.
 • Childhood history: prematurity, childhood infections such as 
whooping cough or measles.
 • Travel history: may be relevant in assessing risk factors for 
­tuberculosis. 
28
Respiratory disease 
Veronica White and Prina Ruparelia
CORE SKILLS AND KNOWLEDGE
Respiratory medicine is an exciting and varied specialty caring 
for patients with a range of acute and chronic conditions. One-­
third of visits to primary care are due to a respiratory complaint, 
and respiratory conditions are the reason for one-­quarter of 
medical admissions to hospital.
Respiratory physicians provide a large amount of inpatient 
care, for acute problems such as pneumonia or exacerbations 
of chronic obstructive pulmonary disease and other chronic 
respiratory conditions. Outpatient care is given in general clin­
ics (for the initial investigation and diagnosis of patients with 
respiratory symptoms) and in more specialist ones (for long-­
term follow-­up of individual conditions). In specialist clinics, 
care is shared with community teams and nurse specialists 
to promote the health and quality of life of patients, through 
education, self-­management and admission-­avoidance strate­
gies. Practical procedures performed by respiratory physicians 
include bronchoscopy, endobronchial ultrasound scanning and 
pleural interventions.
Key skills in respiratory medicine include:
 • managing respiratory emergencies, including type 1 and type 
2 respiratory failure, massive pleural effusion, pneumothorax 
and large-­volume haemoptysis
 • interpreting basic examination findings and respiratory in­
vestigations, i.e. chest X-­rays (Fig. 28.1), arterial blood gas 
analysis and spirometry, with confidence
 • understanding common treatments for respiratory condi­
tions, including inhaled and nebulized medications, home 
oxygen therapy and non-­invasive ventilation.
Respiratory medicine can be learned through attending gen­
eral and subspecialty respiratory clinics (e.g. lung cancer, tuber­
culosis or sleep clinics), observing specialist investigations such 
as lung function measurement or bronchoscopy, attending clin­
ics and home visits with specialist nurses, and at every opportu­
nity interpreting arterial blood gases and using the results to alter 
oxygen delivery or assisted ventilation systems.
Clinical skills for respiratory medicine 
927
Function of the respiratory system 
930
Anatomy 
930
Physiology 
932
Clinical approach to the patient with respiratory 
disease 
936
Investigation of respiratory disease 
939
Diseases of the upper respiratory tract 
945
Obstructive respiratory disease 
949
Asthma 
949
Chronic obstructive pulmonary disease 
955
Obstructive sleep apnoea 
960
Smoking 
963
Respiratory infection 
963
Pneumonia 
963
Tuberculosis 
967
Pleural disease 
972
Pleural effusion 
972
Pneumothorax 
973
Tumours of the Respiratory Tract 
975
Bronchiectasis 
982
Cystic fibrosis 
983
Interstitial Lung Diseases 
985
Sarcoidosis 
985
Idiopathic pulmonary fibrosis 
988
Hypersensitivity pneumonitis 
989
Rare interstitial lung diseases 
991
Lung and Heart-Lung Transplantation 
994
Occupational Lung Disease 
995
Miscellaneous Respiratory Disorders 
997
Disorders of the Diaphragm 
997
Mediastinal Lesions 
998', 4202),
   ('5252c707-d063-595a-959d-43015f12d441', 'KUMAR_CLARK_10_2017', 'KC-C28', 928, 946, 0, '28
928  Respiratory disease 
Examination
 
 
8VHRIDFFHVVRU\PXVFOHV
,QWHUFRVWDOLQGUDZLQJ
2HGHPDOHJRUVDFUDOLI
O\LQJGRZQ
5LJKWKHDUWIDLOXUH
6HFRQGDU\WRSXOPRQDU\
K\SHUWHQVLRQ
$QDHPLD
+RUQHU¶VV\QGURPH
3XUVHGOLSV
1RVH±EHDN\
&HQWUDOF\DQRVLV
-XJXODUYHQRXVSUHVVXUH
5DLVHG
3XOVDWLOH
&2UHWHQWLRQIODS
%RXQGLQJSXOVH
&OXEELQJ
7DUVWDLQLQJ
3HULSKHUDOF\DQRVLV
''HHSYHLQWKURPERVLV
6SXWXP
9ROXPH↑↑EURQFKLHFWDVLV
0XFRSXUXOHQWLQIHFWLRQ
3XUXOHQWJUHHQ LQIHFWLRQ
%ORRGVWDLQHGFDQFHU
SXOPRQDU\HPEROLVP
WXEHUFXORVLVEURQFKLHFWDVLV
(QGRIWKHEHG
3RVWXUH±O\LQJIODWRUUDLVHG
&RORXU±F\DQRVHG"
5HVSLUDWRU\UDWH
3DLQRQEUHDWKLQJSOHXULWLF"
)HYHU
&DFKH[LD
,QVSHFWLRQ
&RORXU
%UHDWKOHVVQHVV
''HIRUPLW\
6FDUV
6\PPHWU\RIPRYHPHQW
$EGRPLQDOSDUDGR[
GLDSKUDJPZHDNHQLQJ
+\SHULQIODWLRQ
3URPLQHQWYHLQV
69&REVWUXFWLRQ
,QWHUFRVWDOLQGUDZLQJ
6FROLRVLV
3DOSDWLRQ
7UDFKHDOSRVLWLRQ
&ULFRVWHUQDOGLVWDQFH
6XSUDFODYLFXODUIRVVDQRGHV
$SH[EHDW
7HQGHUQHVV
&RVWRFKGULWLV
5LEIUDFWXUH
/LYHU
3RVLWLRQORZO\LQJ
(QODUJHPHQW
3HUFXVVLRQ
''XOO
&RQVROLGDWLRQ
&ROODSVH

6WRQ\GXOO
)OXLGHIIXVLRQ
+\SHUUHVRQDQW
3QHXPRWKRUD[
$XVFXOWDWLRQ
1RUPDORU
YHVLFXODU
%URQFKLDOEUHDWKLQJ
:KHH]H
0RQRSKRQLFVLQJOHODUJHDLUZDUREVWUXFWLRQ
3RO\SKRQLFQDUURZLQJRIVPDOODLUZD\V
&UDFNOHV
&RDUVHFRQVROLGDWLRQEURQFKLHFWDVLV
)LQHODWHLQVSLUDWRU\SXOPRQDU\RHGHPDOXQJILEURVLV
3OHXUDOUXE
9RFDOUHVRQDQFH
([DPLQLQJWKHFKHVW', 1562),
   ('8015cb33-f797-5c8a-aeaf-c4e37beafd95', 'KUMAR_CLARK_10_2017', 'KC-C28', 929, 947, 0, '28
Clinical skills for respiratory medicine  929
1. Preliminaries
2. Trachea
3. Mediastinum
4. Heart size
5. Diaphragm
7. Lungs
• Patient details:
- Which patient, how old, when was this image taken?
• X-ray details:
- Is it a posteroanterior or anteroposterior projection?
- Is the patient rotated?
- Is there adequate penetration?
- Has the patient taken an adequate breath?
• Compare where available to previous X-ray images
• The trachea should be widely patent and should be 
central in the chest
• The trachea may be pulled towards areas of fibrosis or 
collapse
• It may be pushed away by masses, a goitre, 
lymphadenopathy, large pleural effusion or a tension 
pneumothorax
• The aortic notch should be just visible 
• The left hilum should be slightly higher than the right
• The hila should be symmetrical in size
• The mediastinum is widened by lymphadenopathy, 
masses such as thymoma, and aortic aneurysm
• The hila may be pulled up or down by collapsed lobes, or 
enlarged by the presence of a tumour
• Heart size should be less than 50% of the thoracic 
width on a PA chest film
• Assess heart borders
• Cardiomegaly may be caused by hypertension, valvular 
disease, heart failure or cardiomyopathy
• Loss of right heart border may suggest right middle lobe 
pathology
• Loss of left heart border suggests lingular pathology
• The right hemidiaphragm is usually higher than the left 
• Look for air/gas under the diaphragm and for elevation 
of the diaphragm on either side
• Air or gas under the diaphragm indicates a perforated 
abdominal viscus
• A hemidiaphragm may be pulled up from above by lobar 
collapse, or pushed up from below by a large mass
6. Pleura
• The costophrenic angles should be clearly visible 
• Look for lung markings extending to the chest wall
• Look for evidence of a lung edge
• Loss of the costophrenic angle is usually due to the presence 
of pleural effusions 
• Larger pleural effusions may cause a ''white out'' on one side
• Loss of lung markings or a visible lung edge suggests a 
pneumothorax
• Is there consolidation of the upper lobe (stops at 
horizontal fissure), middle lobe/lingula (heart edge 
unclear) or lower lobe (diaphragm unclear)? 
• Inspect each part of the lung looking for round 
shadows
• Inspect the lung parenchyma for interstitial changes
• Areas of consolidation may often be restricted to a lobe and 
are usually caused by pneumonia. An air bronchogram 
(airways outlined) or evidence of cavitation may be seen
• Rounded shadows may be caused by cancer, inflammatory 
lesions, such as tuberculosis or fungal disease
• Interstitial changes may be caused by pulmonary oedema or 
fibrosis
8. Bones
• Inspect all ribs for evidence of fractures
• Faint bones imply osteopenia 
• Are there lytic lesions?
• Think of systemic diseases:
- Osteoporosis may cause osteopenia or fractures
- Solid organ cancers or myeloma can cause lytic lesions
10. Miscellaneous
• Look for any externally applied devices
• Nasogastric tubes should bisect the carina and cross the 
diaphragm
• Chest drains should terminate in the pleural space
• Central venous catheters should end just above the right atrium
• Pacemaker wires, and sternotomy wires imply cardiac disease
9. Soft tissue 
• Observe the soft tissue around the rib cage 
• Air within the skin suggests surgical emphysema
Fig. 28.1  A systematic ten-­step approach to chest X-­ray interpretation.', 3405),
   ('66e8ffbe-94a3-5f97-a49e-9d4463e91f1d', 'KUMAR_CLARK_10_2017', 'KC-C28', 930, 948, 0, '28
930  Respiratory disease 
FUNCTION OF THE RESPIRATORY 
SYSTEM
The respiratory system has several key functions, the principal ones 
being to extract oxygen from the external environment and to dis­
pose of carbon dioxide. This requires the lungs to function as effi­
cient bellows, bringing in fresh air and delivering it to the alveoli, and 
expelling used air at an appropriate rate. Gas exchange is achieved 
by exposing thin-­walled capillaries to the alveolar gas and matching 
ventilation to blood flow through the pulmonary capillary bed. The 
excretion of carbon dioxide by the lungs is involved in acid-base 
homeostasis.
The lungs expose a large surface area of body tissue to the 
external environment in order to achieve gas exchange, and hence 
they can be damaged by dusts, gases and infective agents. Host 
defence is therefore a key priority for the lung and is achieved by a 
combination of structural and immunological defences.
The pulmonary circulation also acts as a blood pool reservoir 
that can allow the body to respond readily to increased oxygen 
demands in exercise. The lungs act as a filtration system for small 
pulmonary emboli. The pulmonary circulation also plays a role in 
innate immunity: for example, in de-­priming neutrophils.
Finally, the lungs have a role in speech, as the passage of air 
through the vocal cords is necessary for phonation.
Anatomy
Nose, pharynx and larynx
See pages 907 and 909. 
Trachea, bronchi and bronchioles
The trachea is 10-12 cm in length. It lies slightly to the right of the 
midline and divides at the carina into right and left main bronchi. 
The carina lies under the junction of the manubrium sterni and the 
second right costal cartilage. The right main bronchus is more verti­
cal than the left and inhaled material is therefore more likely to end 
up in the right lung.
The right main bronchus divides into the upper lobe bronchus 
and the intermediate bronchus, which further subdivides into the 
middle and lower lobe bronchi. On the left the main bronchus 
divides into upper and lower lobe bronchi only. Each lobar bronchus 
further divides into segmental and subsegmental bronchi. There are 
about 25 divisions in all between the trachea and the alveoli.
The first seven divisions are bronchi that have:
 • walls consisting of cartilage and smooth muscle
 • an epithelial lining with cilia and goblet cells
 • submucosal mucus-­secreting glands
 • endocrine cells.
The next 16-18 divisions are bronchioles that have:
 • no cartilage and a muscular layer that progressively becomes 
thinner
 • a single layer of ciliated cells but very few goblet cells
 • granulated Clara cells that produce a surfactant-­like substance.
The ciliated epithelium is a key defence mechanism. Each cell 
bears approximately 200 cilia beating at 1000 beats per minute 
(b.p.m.) in organized waves of contraction. Mucus, which contains 
macrophages, cell debris, inhaled particles and bacteria, is moved 
by the cilia towards the larynx at about 1.5 cm/min (the ''mucociliary 
escalator''; see later).
The bronchioles finally divide within the acinus into smaller 
respiratory bronchioles that have alveoli arising from the surface 
(Fig. 28.2). Each respiratory bronchiole supplies approximately 200 
alveoli via alveolar ducts. The term ''small airways'' refers to bron­
chioles of less than 2 mm; the average lung contains about 30 000 
of these. 
Alveoli
There are approximately 300 million alveoli in each lung. Their total 
surface area is 40-80 m2. The epithelial lining consists mainly of 
type I pneumocytes (Fig. 28.3). These cells have an extremely thin 
layer of cytoplasm, which only offers a thin barrier to gas exchange. 
Type I cells are connected to each other by tight junctions that limit 
the movements of fluid in and out of the alveoli. Alveoli are not com­
pletely airtight; many have holes in the alveolar wall, allowing com­
munication between alveoli of adjoining lobules (pores of Kohn).
Type II pneumocytes are slightly more numerous than type I 
cells but cover less of the epithelial lining. They are found generally 
in the borders of the alveolus and contain distinctive lamellar vacu­
oles, which are the source of surfactant. Type I pneumocytes are 
The ''top 10'' respiratory 
conditions
 • Acute and chronic cough
 • Asthma
 • Chronic obstructive pulmonary 
disease (COPD)
 • Pneumonia
 • Pulmonary tuberculosis
 • Pneumothorax
 • Pleural effusions
 • Lung cancer
 • Bronchiectasis
 • Interstitial lung disease 
The ''top 10'' concepts in 
respiratory medicine
 • Smoking cessation
 • Self-­management of chronic 
conditions
 • Admission avoidance
 • Home oxygen therapy
 • Multidisciplinary cancer care
 • Respiratory failure
 • Atopy
 • The ''treatment ladder'' approach 
to asthma and COPD
 • Management of chest drains
 • Diagnosis and staging of lung 
cancer 
The ''top 10'' respiratory 
medications
 • Oxygen
 • β2 agonists
 • Antimuscarinics
 • Oral and inhaled corticosteroids
 • Combination inhalers
 • Antihistamines
 • Leukotriene receptor antagonists
 • Mucolytics
 • Monoclonal antibodies
 • Antifibrotics
Box 28.1 Core content in respiratory medicine
,QFRPSOHWH
OREXODUVHSWXP
5HVSLUDWRU\
EURQFKLROHV
$OYHRODUVDFV
$OYHRODUGXFWV
$OYHROL



7HUPLQDO
EURQFKLROH
2XWOLQH
RIDFLQXV
Fig. 28.2  Branches of a terminal bronchiole ending in the alveo­
lar sacs.', 5397),
   ('b120ddac-972f-509d-bccd-612f2660714c', 'KUMAR_CLARK_10_2017', 'KC-C28', 931, 949, 0, '28
Function of the respiratory system  931
derived from type II cells. Large alveolar macrophages are present 
within the alveoli and assist in defending the lung. 
Lungs
The lungs are separated into lobes by invaginations of the pleura, 
which are often incomplete. The right lung has three lobes, whereas 
the left lung has two. The positions of the oblique fissures and the 
right horizontal fissure are shown in Fig. 28.4. The upper lobe lies 
mainly in front of the lower lobe and therefore physical signs on the 
right side in the front of the chest are due to lesions of the upper 
lobe or the middle lobe. 
Pleura
The pleura is a layer of connective tissue covered by a simple 
squamous epithelium. The visceral pleura covers the surface of the 
lung, lines the interlobar fissures, and is continuous at the hilum 
with the parietal pleura, which lines the inside of the hemithorax. 
At the hilum, the visceral pleura continues alongside the branching 
bronchial tree for some distance before reflecting back to join the 
parietal pleura. In health, the pleurae are in apposition, apart from a 
small quantity of lubricating fluid. 
Diaphragm
The diaphragm is covered by parietal pleura above and peritoneum 
below. The diaphragmatic muscle fibres arise from the lower ribs 
and insert into the central tendon. Motor and sensory nerve fibres 
go separately to each half of the diaphragm via the phrenic nerves. 
Fifty per cent of the muscle fibres are of the slow-­twitch type with a 
low glycolytic capacity; they are relatively resistant to fatigue. 
Pulmonary vasculature and lymphatics
The lung has a dual blood supply, receiving deoxygenated blood 
from the right ventricle via the pulmonary artery and oxygenated 
blood via the bronchial circulation.
The pulmonary artery divides to accompany the bronchi. The 
arterioles accompanying the respiratory bronchioles are thin-­walled 
and contain little smooth muscle. The pulmonary venules drain lat­
erally to the periphery of the lobules, pass centrally in the interlobu­
lar and intersegmental septa, and eventually join to form the four 
main pulmonary veins.
The bronchial circulation arises from the descending aorta. 
These bronchial arteries supply tissues down to the level of the 
respiratory bronchiole. The bronchial veins drain into the pulmonary 
veins, forming part of the normal physiological shunt.
Lymphatic channels lie in the interstitial space between the alve­
olar cells and the capillary endothelium of the pulmonary arterioles.
The tracheobronchial lymph nodes are arranged in five main 
groups: pulmonary, bronchopulmonary, subcarinal, superior tracheo­
bronchial and paratracheal. For practical purposes, these form a con­
tinuous network of nodes from the lung substance up to the trachea. 
Nerve supply to the lung
The innervation of the lung remains incompletely understood. Para­
sympathetic and sympathetic fibres (from the vagus and sympa­
thetic chain, respectively) accompany the pulmonary arteries and 
the airways. Airway smooth muscle is innervated by vagal afferents, 
postganglionic muscarinic vagal efferents and vagally derived non-­
adrenergic non-­cholinergic (NANC) fibres, which use a range of 
neurotransmitters. Three muscarinic receptor subtypes have been 
,QFRPSOHWH
OREXODUVHSWXP
&\WRSODVPRI
W\SH,FHOO
&DSLOODU\
HQGRWKHOLXP
7\SH,,
SQHXPRF\WHV
0DFURSKDJH
%ORRGYHVVHO
5HGEORRGFHOO
,QWHUVWLWLXP
$OYHROXV
$OYHROXV
$OYHROXV
Fig. 28.3  The structure of alveoli, showing the pneumocytes and 
capillaries.
8SSHUOREH
7UDFKHD
QGULE
/HIW
GLDSKUDJP
$SH[RIWKHOXQJ
$SH[RIWKHOXQJ
$QJOHRI
/RXLVDQG
FDULQD
WKWKRUDFLF
YHUWHEUD
2EOLTXH
JUHDWHU
ILVVXUH
3OHXUD
WKULE
WKULE
5LJKW
GLDSKUDJP
/LYHU
WKULE
0LGGOHOREH
;LSKLVWHUQXP
/RZHUOREH
$QWHULRUHQG
RIKRUL]RQWDO
OHVVHUILVVXUH
3RVWHURDQWHULRU
/DWHUDO
$
%
Fig. 28.4  Surface anatomy of the chest.  (A) Anterior. (B) Lateral.', 3899),
   ('e8740d0c-26bc-5320-93d1-31700d17dc01', 'KUMAR_CLARK_10_2017', 'KC-C28', 932, 950, 0, '28
932  Respiratory disease 
identified: M1 receptors on parasympathetic ganglia, a smaller num­
ber of M2 receptors on muscarinic nerve terminals, and M3 recep­
tors on airway smooth muscle. The parietal pleura is innervated 
from intercostal and phrenic nerves but the visceral pleura has no 
innervation.
Further reading
Albert RK, Spiro SG, Jett JR. Clinical Respiratory Medicine, 4th edn. Chicago: 
Mosby; 2012. 
Physiology
Nose
The major functions of nasal breathing are:
 • to heat and moisten the air
 • to remove particulate matter.
Nasal secretions contain immunoglobulin A (IgA) antibodies, 
lysozyme and interferons. In addition, the cilia of the nasal epithe­
lium move the mucous gel layer rapidly back to the oropharynx, 
where it is swallowed. Bacteria have little chance of settling in the 
nose. Mucociliary protection is less effective against viral infections 
because viruses bind to receptors on epithelial cells. The majority 
of rhinoviruses bind to an adhesion molecule, intercellular adhesion 
molecule 1 (ICAM-­1), which is shared by neutrophils and eosino­
phils. Many noxious gases, such as sulphur dioxide, are almost 
completely removed by nasal breathing. 
Breathing
Lung ventilation can be considered in two parts:
 • the mechanical process of inspiration and expiration
 • the control of respiration to a level appropriate for metabolic 
needs.
Mechanical process
The lungs have an inherent elastic property that causes them to 
tend to collapse away from the thoracic wall, generating a nega­
tive pressure within the pleural space. The strength of this retractive 
force relates to the volume of the lung: at higher lung volumes the 
lung is stretched more, and a greater negative intrapleural pressure 
is generated. Lung compliance is a measure of the relationship 
between this retractive force and lung volume. At the end of a quiet 
expiration the retractive force exerted by the lungs is balanced by 
the tendency of the thoracic wall to spring outwards. At this point, 
respiratory muscles are resting. The volume of air remaining in 
the lung after a quiet expiration is called the functional residual 
capacity (FRC; see Fig. 28.15).
Inspiration from FRC is an active process: a negative intrapleural 
pressure is created by descent of the diaphragm and movement of 
the ribs upwards and outwards through contraction of the intercos­
tal muscles. During tidal breathing in healthy individuals, inspiration 
is almost entirely due to contraction of the diaphragm. More vigor­
ous inspiration requires the use of accessory muscles of ventila­
tion (sternomastoid and scalene muscles). Respiratory muscles are 
similar to other skeletal muscles but are less prone to fatigue. How­
ever, inspiratory muscle fatigue contributes to respiratory failure in 
patients with severe chronic airflow limitation and in those with pri­
mary neurological and muscle disorders.
At rest or during low-­level exercise, expiration is passive and 
results from the natural tendency of the lung to collapse. Forced 
expiration involves activation of accessory muscles, chiefly those of 
the abdominal wall, which help to push up the diaphragm. 
Control of respiration
Coordinated respiratory movements result from rhythmical dis­
charges arising in an anatomically ill-­defined group of intercon­
nected neurones in the reticular substance of the brainstem, known 
as the respiratory centre. Motor discharges from the respiratory 
centre travel via the phrenic and intercostal nerves to the respiratory 
musculature.
Ventilation is controlled by a combination of neurogenic and 
chemical factors (Fig. 28.5). In healthy individuals the main driver 
for respiration is the arterial pH, which is closely related to the partial 
pressure of carbon dioxide in arterial blood. Oxygen levels in arte­
rial blood are usually above the level that triggers respiratory drive. 
Typical normal values are shown in Box 28.2.
Breathlessness on physical exertion is normal and not con­
sidered a symptom unless the level of exertion is very light, such 
as when walking slowly. Surveys of healthy Western populations 
reveal that over 20% of the general population report themselves 
as breathless on relatively minor exertion. Although breathlessness 
is a very common symptom, the sensory and neural mechanisms 
underlying it remain obscure. The sensation of breathlessness is 
derived from at least three sources:
 • changes in lung volume, sensed by receptors in thoracic wall 
muscles signalling changes in their length
 • tension developed by contracting muscles, sensed by Golgi 
tendon organs
 • central perception of the sense of effort. 
Airways of the lungs
From the trachea to the periphery, the airways decrease in size but 
increase in number. Overall, the cross-­sectional area available for 
airflow increases as the total number of airways increases. The air­
flow rate is greatest in the trachea and slows progressively towards 
the periphery (since the velocity of airflow depends on the cross-­
sectional area). In the terminal airways, gas flow occurs solely by 
diffusion. The resistance to airflow is very low (0.1-0.2 kPa/L in a 
normal tracheobronchial tree), steadily increasing from the small to 
the large airways.
Airways expand as the lung volume increases. At full inspiration 
(total lung capacity, TLC) they are 30-40% larger in calibre than at 
full expiration (residual volume, RV). In chronic obstructive pulmo­
nary disease (COPD) the small airways are narrowed but this can be 
partially compensated by breathing closer to TLC.
Control of airway tone
Bronchomotor tone is maintained by vagal efferent nerves and can 
be reduced by atropine or β-­adrenoceptor agonists. Adrenoceptors 
on the surface of bronchial muscles respond to circulating cate­
cholamines; there is no direct sympathetic innervation. Airway tone 
shows a circadian rhythm, which is greatest at 04.00 and lowest 
in the mid-­afternoon. Tone can be increased transiently by inhaled 
stimuli acting on epithelial nerve endings, which trigger reflex 
bronchoconstriction via the vagus. These stimuli include cigarette 
smoke, solvents, inert dust and cold air. Airway responsiveness to 
these stimuli increases following respiratory tract infections, even in 
healthy subjects. In asthma the airways are very irritable, and as the 
circadian rhythm remains the same, asthmatic symptoms are usu­
ally worse in the early morning. 
Airflow
Movement of air through the airways results from a difference 
between atmospheric pressure and the pressure in the alveoli; alve­
olar pressure is negative in inspiration and positive in expiration.', 6657),
   ('b00cd53c-0026-5c8b-a08c-5f2996a16218', 'KUMAR_CLARK_10_2017', 'KC-C28', 933, 951, 0, '28
Function of the respiratory system  933
During quiet breathing the pleural pressure is negative throughout 
the breathing cycle. With vigorous expiratory efforts (e.g. cough) 
the pleural pressure becomes positive (up to 10 kPa). This com­
presses the central airways, but the smaller airways do not close off 
because the driving pressure for expiratory flow (alveolar pressure) 
is also increased. 
Flow-volume loops
The relationship between maximal flow rates and lung volume is 
demonstrated by the maximal flow-volume (MFV) loop (Fig. 28.6A).
In subjects with healthy lungs, maximal flow rates are rarely 
achieved even during vigorous exercise. However, in patients with 
severe COPD, limitation of expiratory flow occurs even during tidal 
breathing at rest (Fig. 28.6B). To increase ventilation, these patients 
have to breathe at higher lung volumes and allow more time for 
expiration, both of which reduce the tendency for airway collapse. 
To compensate, they increase flow rates during inspiration, where 
there is relatively less flow limitation.
The volume that can be forced in from the residual volume in 
1 second (FIV1) will always be greater than that which can be forced 
out from TLC in 1 second (FEV1). Thus, the ratio of FEV1 to FIV1 
is less than 1. The only exception to this is when there is signifi­
cant obstruction to the airways outside the thorax, such as tracheal 
tumour or retrosternal goitre. Expiratory airway narrowing is pre­
vented by tracheal resistance, and expiratory airflow becomes more 
effort-­dependent. During forced inspiration, this same resistance 
causes such negative intraluminal pressure that the trachea is com­
pressed by the surrounding atmospheric pressure. Inspiratory flow 
thus becomes less effort-­dependent, and the ratio of FEV1 to FIV1 
is greater than 1. This phenomenon, and the characteristic flow-
volume loop, are diagnostic of extrathoracic airways obstruction 
(Fig. 28.6C). 
Ventilation and perfusion relationships
For optimum gas exchange there must be a match between ventila­
tion of the alveoli ( ˙V) and their perfusion ( ˙Q). However, in reality there 
is variation in the (
˙Q
˙VA/
) ratio in both normal and diseased lungs (Fig. 
28.7). In the normal lung, both ventilation and perfusion are greater at 
the bases than at the apices but the gradient for perfusion is steeper, 
so the net effect is that ventilation exceeds perfusion towards the 
apices while perfusion exceeds ventilation at the bases. Other 
1HXURJHQLFIDFWRUV
9ROXQWDU\FRQWURO
$Q[LHW\K\VWHULD
3XOPRQDU\UHFHSWRUV
VHQVLWLYHWRVWUHWFKDQG
EURQFKLDOLUULWDWLRQ
6WLPXODWHGLQDVWKPD
SXOPRQDU\HPEROLVP
SQHXPRQLD
-X[WDFDSLOODU\-UHFHSWRUV
6WLPXODWHGE\DVWKPD
SXOPRQDU\FRQJHVWLRQ
+HDUWIDLOXUH
0XVFOHDQGMRLQWUHFHSWRUV
6WLPXODWHGE\H[HUFLVH
0XVFOHDQGMRLQW
$LUZD\V
DQGOXQJ
SDUHQFK\PD
&RUWH[
%UDLQVWHP
&KHVWZDOO
UHFHSWRUV
5HVSLUDWRU\FHQWUH
6WLPXODWHGE\
3D&2DQG
>+@
&DURWLGDQG
DRUWLFERGLHV
6WLPXODWHGE\
3D2N3D
&KHPLFDOVWLPXOL
Fig. 28.5  Chemical and neurogenic factors in the control of ventilation.  The strongest stimulant to 
ventilation is a rise in PaCO2, which increases [H+] in cerebrospinal fluid. Sensitivity to this may be lost in 
chronic obstructive pulmonary disease. In these patients, hypoxaemia is the chief stimulus to respira­
tory drive; oxygen treatment may therefore reduce respiratory drive and lead to a further rise in PaCO2. 
An increase in [H+] due to metabolic acidosis, as in diabetic ketoacidosis, will increase ventilation with a 
fall in PaCO2, causing deep sighing (Kussmaul) respiration. The respiratory centre is depressed by severe 
hypoxaemia and sedatives (e.g. opiates).
In a typical normal adult at rest:
 • Pulmonary blood flow is about 5 L/min
 • This carries 11 mmol/min (250 mL/min) of O2 to tissues
 • Ventilation is about 6 L/min
 • This removes 9 mmol/min (200 mL/min) of CO2 from the body
 • Normal pressure of oxygen in arterial blood (PaO2) is 11-13 kPa
 • Normal pressure of carbon dioxide in arterial blood (PaCO2) is 
4.8-6.0 kPa
Box 28.2 Normal values for respiratory physiology', 4128),
   ('d0e6451d-261b-54a3-bdca-e083bbca865d', 'KUMAR_CLARK_10_2017', 'KC-C28', 934, 952, 0, '28
934  Respiratory disease 
causes of mismatch include direct shunting of deoxygenated blood 
through the lung without passing through alveoli (e.g. the bronchial 
circulation) and areas of lung that receive no blood (e.g. anatomical 
deadspace, bullae and areas of under-­perfusion during acceleration 
and deceleration, e.g. in aircraft and high-­performance cars).
An increased physiological shunt results in arterial hypoxaemia 
since it is not possible to compensate for some of the blood being 
under-­oxygenated by increasing ventilation of the well-­perfused 
areas. An increased physiological deadspace just increases the 
work of breathing and has less impact on blood gases since the 
normally perfused alveoli are well ventilated. In more advanced dis­
ease this compensation cannot occur, leading to increased alveolar 
and arterial PCO2 (PaCO2), together with hypoxaemia, which cannot 
be compensated for by increasing ventilation.
Hypoxaemia occurs more readily than hypercapnia because of 
the different ways in which oxygen and carbon dioxide are carried 
in the blood. Carbon dioxide is carried in three forms (in bicarbon­
ate, in carbamino compounds and in simple solution) but the vol­
ume carried is proportional to the partial pressure of CO2. Oxygen is 
carried in chemical combination with haemoglobin in the red blood 
cells, with a non-­linear relationship between the volume carried and 
the partial pressure. Alveolar hyperventilation reduces the alveolar 
PCO2 (PACO2) and diffusion leads to a proportional fall in the carbon 
dioxide content of the blood (PaCO2). However, as the haemoglo­
bin is already saturated with oxygen, increasing the alveolar PO2 
through hyperventilation will not increase blood oxygen content. 
This means that hypoxaemia due to physiological shunting cannot 
be compensated for by hyperventilation.
In individuals who have mild degrees of mismatch the PaO2 and 
PaCO2 will still be normal at rest. Increasing the requirements for 
gas exchange by exercise will widen the mismatch and the PaO2 
will fall. Mismatch is by far the most common cause of arterial 
hypoxaemia. 
Alveolar stability
Pulmonary alveoli are polygonal spaces within a sponge-­like matrix. 
Surface tension acting at the curved internal surface tends to cause 
the alveoli to decrease in size. The surface tension within the alveoli 
would make the lungs extremely difficult to distend, were it not for 
the presence of surfactant, which reduces surface tension so that 
alveoli remain stable. 
Defence mechanisms of the respiratory tract
Pulmonary disease often results from a failure of the normal host 
defence mechanisms of the healthy lung (Fig. 28.8). These can be 
divided into physical, physiological, humoral and cellular mechanisms.
Physical and physiological mechanisms
Humidification
This prevents dehydration of the epithelium. 


([SLUDWRU\
IORZSHU/
,QVSLUDWRU\
IORZSHU/





3()5
)5&
59
7/&
9ROXPH
/
([HUFLVHWLGDOEUHDWK
5HVWLQJWLGDOEUHDWK
1ROXQJGLVHDVH
$
([SLUDWRU\
IORZSHU/
,QVSLUDWRU\
IORZSHU/


9ROXPH
/
([HUFLVH
5HVW
6HYHUHDLUIORZOLPLWDWLRQ
%

7/&
59
([WUDWKRUDFLF
WUDFKHDOREVWUXFWLRQ
&

7/&
59

,QWUDWKRUDFLFODUJH
DLUZD\REVWUXFWLRQ
''
Fig. 28.6  Flow-volume loops.  (A-B) Maximal flow-volume loops, showing the relationship between 
maximal flow rates on expiration and inspiration. (A) Normal subject. (B) Severe airflow limitation. 
Flow-volume loops during tidal breathing at rest (starting from the functional residual capacity, FRC) and 
during exercise are also shown. The highest flow rates are achieved when forced expiration begins at total 
lung capacity (TLC) and represent the peak expiratory flow rate (PEFR). As air is blown out of the lung, so 
the flow rate decreases until no more air can be forced out, a point known as the residual volume (RV). 
Because inspiratory airflow is dependent only on effort, the shape of the maximal inspiratory flow-vol­
ume loop is quite different, and inspiratory flow remains at a high rate throughout the manoeuvre. (C-D) 
Flow-volume loops in large airway (tracheal) obstruction, showing plateauing of maximal expiratory 
flow. (C) Extrathoracic tracheal obstruction with a proportionally greater reduction of maximal inspiratory 
(as opposed to expiratory) flow rate. (D) Intrathoracic large airway obstruction; the expiratory plateau 
is more pronounced and inspiratory flow rate is less reduced than in (C). In severe airflow limitation, the 
ventilatory demands of exercise cannot be met (compare A, B), greatly reducing effort tolerance.', 4601),
   ('4b33120f-1282-5d05-ab6c-2cddc04ec4a2', 'KUMAR_CLARK_10_2017', 'KC-C28', 935, 953, 0, '28
Function of the respiratory system  935
Particle removal
Over 90% of particles of more than 10 μm in diameter are removed in 
the nostril or nasopharynx. This includes most pollen grains, which 
are typically greater than 20 μm in diameter. Particles between 5 and 
10 μm become impacted at the carina. Particles of less than 1 μm 
tend to remain airborne: thus the particles capable of reaching the 
deep lung are those in the 1-5 μm range. 
Particle expulsion
This is facilitated by coughing, sneezing or gagging. 
Respiratory tract secretions
The mucus of the respiratory tract is a gelatinous substance consisting 
of water and highly glycosylated proteins (mucins). The mucus forms 
a thick gel that is relatively impermeable to water and floats on a liquid 
or sol layer found around the cilia of the epithelial cells (see Fig. 28.8). 
The gel layer is secreted from goblet cells and mucus glands as dis­
tinct globules that coalesce increasingly in the central airways to form 
a more or less continuous mucus blanket. In addition to the mucins, 
the gel contains various antimicrobial molecules (lysozyme, defensins), 
specific antibodies (IgA) and cytokines, which are secreted by cells in 
airways and are incorporated into the mucus gel. Bacteria, viruses and 
other particles become trapped in the mucus and are either inactivated 
or simply expelled before they can do any damage. Under normal 
conditions the tips of the cilia engage with the undersurface of the gel 
phase and by coordinated movement they push the mucus blanket 
upwards and outwards to the pharynx, where it is either swallowed or 
coughed up. One of the major long-­term effects of cigarette smoking 
is a reduction in mucociliary transport. This contributes to recurrent 
infection and prolongs contact with carcinogenic material. Air pollut­
ants, local and general anaesthetics, and products of bacterial and viral 
infection also reduce mucociliary clearance.
Congenital defects in mucociliary transport (cystic fibrosis and 
immotile cilia syndrome) lead to recurrent infections and eventually 
to bronchiectasis. 
The respiratory microbiome
It has always been thought that the lower respiratory tract is sterile. 
Recent evidence has shown that there is a resident bacterial flora 
that is very similar to that of the mouth. The composition of the 
respiratory microbiome is determined by three factors:
 • microbial immigration, e.g. by inhalation, or microaspiration 
from the gastrointestinal tract
 • local growth conditions for the bacteria, e.g. temperature, pH, 
nutrients, concentration and activation of local inflammatory 
cells, and epithelial cell interactions
 • microbial elimination by the usual mechanisms, i.e. the muco­
ciliary escalator, coughing and the innate and adaptive humoral 
mechanisms.
All of these factors will change in both acute and chronic lung 
conditions when there is an increase in pathological bacteria. This 
respiratory tract dysbiosis causes a dysregulation of the local 
immune response and favours the growth of bacteria: for example, 
in the exacerbation of chronic diseases in which inflammation is 
perpetuated. The background composition of the bacterial micro­
biome in different conditions might favour exacerbations. 
Humoral and cellular mechanisms
Non-­specific soluble factors
 • Alpha-­antitrypsin (α1-­antiprotease, see p. 1302) in lung se­
cretions is derived from plasma. It inhibits chymotrypsin and 
trypsin, and neutralizes proteases, including neutrophil elastase.
 • Antioxidant defences include enzymes such as superoxide dis­
mutase and low-­molecular-­weight antioxidant molecules (ascor­
bate, urate) in the epithelial lining fluid.
 • Lysozyme is an enzyme found in granulocytes that has bacteri­
cidal properties.
D3K\VLRORJLFDO
GHDGVSDFH
9HQWLODWLRQZLWK
UHGXFHGSHUIXVLRQ
9
$4!
E1RUPDO
9HQWLODWLRQDQG
SHUIXVLRQ
9
$4 
F3K\VLRORJLFDO
VKXQW
3HUIXVLRQZLWK
UHGXFHGYHQWLODWLRQ
9
$4
%ORRG
YHVVHOV
&DXVHV
3XOPRQDU\HPEROLVP
3XOPRQDU\DUWHULWLV
1HFURVLVRU¿EURVLV
ORVVRIFDSLOODU\EHG
&DXVHV
$LUZD\OLPLWDWLRQ
DVWKPDDQG&23''
/XQJFROODSVHRU
FRQVROLGDWLRQ
/RVVRIHODVWLF
WLVVXHHPSK\VHPD
''LVHDVHRIWKH
FKHVWZDOO
D
F
E
Fig. 28.7  Relationships between ventilation and perfusion: 
the alveolar-capillary interface.  The centre (b) shows normal 
ventilation and perfusion. On the left (a) there is a block in perfusion 
(physiological deadspace), while on the right (c) there is reduced 
ventilation (physiological shunting). COPD, chronic obstructive 
pulmonary disease.
/XPLQDOFHOO
HJ
QHXWURSKLO
O\PSKRF\WH
6HFUHWRU\FRPSRQHQW
6XUIDFHPXFRVDO
PDFURSKDJH
6HFUHWRU\
,J$
*REOHWFHOO
(SLWKHOLXP
/XPHQ
*HOSKDVH
6ROSKDVH
&LOLD
/DPLQD
SURSULD
%DVHPHQWPHPEUDQH
,J*
0DVW
FHOO
3ODVPD
FHOO
0XFXV
JODQG
,J$
-FKDLQ
Fig. 28.8  Defence mechanisms present at the epithelial surface.', 4915),
   ('8bf5d157-e7d0-5b1d-b132-d9a52f426bee', 'KUMAR_CLARK_10_2017', 'KC-C28', 936, 954, 0, '28
936  Respiratory disease 
 • Lactoferrin is synthesized from epithelial cells and neutrophil 
granulocytes, and has bactericidal properties.
 • Interferons are produced by most cells in response to viral in­
fection and are potent modulators of lymphocyte function.
 • Complement in secretions is also derived from plasma. In as­
sociation with antibodies, it plays a major role in cytotoxicity.
 • Surfactant protein A (SPA) is one of four species of surfactant 
protein that opsonize bacteria or particles, enhancing phagocy­
tosis by macrophages.
 • Defensins are bactericidal peptides present in the azurophil 
granules of neutrophils.
 • Dimeric secretory IgA targets specific antigens (see p. 1155). 
Innate and adaptive immunity
These mechanisms act as a defence against microbes, inorganic 
substances such as asbestos, particulate matter such as dust, and 
other antigens. They aid opsonization so that macrophages can 
better ingest foreign material.
With infection, neutrophils migrate out of pulmonary capillar­
ies into the air spaces and phagocytose and kill microbes with, for 
example, antimicrobial proteins (lactoferrin), degradative enzymes 
(elastase) and oxidant radicals. In addition, neutrophil extracellular 
traps ensnare and kill extracellular bacteria. Neutrophils also gener­
ate a variety of mediators, such as tumour necrosis factor alpha 
(TNF-­α), interleukin 1 (IL-­1), and chemokines that attract further 
inflammatory cells that assist with adaptive immunity.
Microbes are detected by host cells by pattern recognition 
receptors, such as toll-­like receptors. These act via nuclear fac­
tor kappa B (NF-­κB) transcription factors in the epithelial cells to 
produce adhesion molecules, chemokines and colony stimulating 
factors to initiate inflammation. Inflammation is necessary for innate 
immunity and host defence but can lead to lung damage; there is a 
fine line between defence and injury.
Further reading
Fahy JV, Dickey BF. Airway mucus function and dysfunction. N Engl J Med 
2010; 363:2233-2247.
Kiley JP, Caler EV. The lung microbiome: a new frontier in pulmonary medicine. 
Ann Am Thorac Soc 2014; 11(Suppl 1):S66-S70. 
CLINICAL APPROACH TO THE 
PATIENT WITH RESPIRATORY 
DISEASE
Clinical features of respiratory disease
Runny, blocked nose and sneezing
Nasal symptoms are extremely common; ''runny nose'' (rhinorrhoea), 
nasal blockage and attacks of sneezing can be caused by allergic rhi­
nitis (see p. 945) and by common colds (p. 945). Nasal secretions are 
usually thin and runny in allergic rhinitis but thicker and discoloured 
with viral infections. Nose bleeds and blood-­stained nasal discharge 
are common and rarely indicate serious pathology. However, a blood-­
stained nasal discharge associated with nasal obstruction and pain 
may be the presenting feature of a nasal tumour (see p. 908). Nasal 
polyps typically present with nasal blockage and loss of smell. 
Cough
Cough (see also p. 908) is the most common symptom of lower respi­
ratory tract disease. It is caused by mechanical or chemical stimulation 
of cough receptors in the epithelium of the pharynx, larynx, trachea, 
bronchi and diaphragm. Afferent receptors go to the cough centre in 
the medulla, where efferent signals are generated to the expiratory 
musculature. Smokers often have a morning cough with a little spu­
tum. A productive cough is the cardinal feature of chronic bronchitis, 
while dry coughing, particularly at night, can be a symptom of asthma 
or acid reflux. Cough also occurs in asthmatics after mild exertion or 
forced expiration. Cough can have no definable pathology; psycho­
logical causes may be blamed but there is only limited evidence.
A worsening cough is the most common presenting symptom 
of lung cancer. The normal explosive character of the cough is lost 
when a vocal cord is paralysed, usually as a result of lung cancer infil­
trating the left recurrent laryngeal nerve. Cough can be accompanied 
by stridor in whooping cough or in laryngeal or tracheal obstruction. 
Sputum
Approximately 100 mL of mucus is produced daily in a healthy, non-­
smoking individual. This flows gradually up the airways, through the 
larynx, and is then swallowed. Excess mucus is expectorated as 
sputum. Cigarette smoking is the most common cause of excess 
mucus production.
Mucoid sputum is clear and white but can contain black specks 
resulting from the inhalation of carbon. Yellow or green sputum is due 
to the presence of cellular material, including bronchial epithelial cells, 
or neutrophil or eosinophil granulocytes. Yellow sputum is not neces­
sarily due to infection, since granulocytes in the sputum, as seen in 
asthma, can give the same appearance. The production of large quan­
tities of yellow or green sputum is characteristic of bronchiectasis. 
Haemoptysis
Haemoptysis (blood-­stained sputum) varies from small streaks of 
blood to massive bleeding. The most common cause of mild haem­
optysis is acute infection (Box 28.3), particularly in exacerbations 
of COPD, but this should not be assumed without investigation. 
Other common causes are pulmonary infarction (e.g. secondary 
to pulmonary embolism), bronchial carcinoma and tuberculosis. 
Pink, frothy sputum is seen in pulmonary oedema, while in bron­
chiectasis the blood is often mixed with purulent sputum. Massive 
haemoptysis (>200 mL of blood in 24 h) is usually due to bronchi­
ectasis or tuberculosis, but can also be caused in later stages of 
lung cancer.
Although a diagnosis can often be made from a chest X-­ray 
(e.g. bronchiectasis, tuberculosis), a normal chest X-­ray does not 
exclude serious disease. However, if the chest X-­ray is normal, CT 
scanning and bronchoscopy are diagnostic in only about 5% of 
patients with haemoptysis. 
 • Malignancy and benign lung tumours, including lung metastasis
 • Pulmonary infection, including bacterial pneumonia, tuberculosis, lung 
abscesses and fungal infection
 • Bronchiectasis, including cystic fibrosis
 • Pulmonary emboli
 • Congestive heart failure
 • Pulmonary fibrosis
 • Pulmonary vasculitis, e.g. Goodpasture''s syndrome, microscopic 
polyangiitis
 • Severe pulmonary hypertension
 • Arteriovenous malformation
 • Chest trauma and foreign bodies
 • Endometriosis
 • Anticoagulation, coagulopathy
 • Drugs, e.g. cocaine, thrombolytics
Box 28.3 Causes of haemoptysis', 6388),
   ('68e27abe-86b4-5d63-926e-03a6126046ba', 'KUMAR_CLARK_10_2017', 'KC-C28', 937, 955, 0, '28
Clinical Approach to the Patient with Respiratory Disease  937
Breathlessness
Dyspnoea (breathlessness) is a sense of awareness of increased 
respiratory effort that is unpleasant and recognized by the patient as 
inappropriate. Patients often complain of tightness in the chest; this 
must be differentiated from angina (Box 28.4). The degree of breath­
lessness should be assessed in relation to the patient''s lifestyle. 
For example, a moderate degree of breathlessness will be totally 
disabling if the patient has to climb many flights of stairs to reach 
home. Breathlessness can be graded using the Medical Research 
Council grading of dyspnoea (Box 28.5).
Orthopnoea (see p. 1028) is breathlessness on lying down. 
While it is classically linked to heart failure, it is partly due to the 
weight of the abdominal contents pushing the diaphragm up into the 
thorax. Such patients may also become breathless on bending over.
Tachypnoea and hyperpnoea are, respectively, an increased 
rate of breathing and an increased level of ventilation. These may 
be appropriate responses (e.g. during exercise).
Hyperventilation is inappropriate overbreathing. This may 
occur at rest or on exertion, and results in a lowering of the alveolar 
and arterial PCO2 (see Box 25.33).
Paroxysmal nocturnal dyspnoea (see p. 1028) describes acute 
episodes of breathlessness at night, typically due to heart failure. 
Wheezing
Wheezing is a common complaint and results from airflow limitation due 
to any cause. The symptom of wheezing is not diagnostic of asthma; 
other causes include vocal cord dysfunction, bronchiolitis and COPD. 
Conversely, wheeze may be absent in the early stages of asthma. 
Chest pain
The most common type of chest pain reported in respiratory dis­
ease is a localized sharp pain, often termed pleuritic. It is made 
worse by deep breathing or coughing and the patient can usually 
localize it. Localized anterior chest pain with tenderness of a cos­
tochondral junction is caused by costochondritis. Shoulder tip pain 
suggests irritation of the diaphragmatic pleura, while central chest 
pain radiating to the neck and arms is likely to be cardiac. Retroster­
nal soreness is associated with tracheitis, and malignant invasion of 
the chest wall causes a constant, severe, dull pain. 
Examination of the respiratory system
Nose
See page 907. 
Chest
Inspection
Observe the patient as they enter the room or move around the bed. 
Are they simply breathless at rest? Do they have a cough or are they 
wheezy? Assessment should be made of mental alertness, cyano­
sis, breathlessness at rest, use of accessory muscles, shape of the 
chest wall, any deformity or scars on the chest and movement on 
both sides. Kyphosis and scoliosis of the spine can cause asymmetry 
of the chest. CO2 intoxication causes coarse tremor or flap of the out­
stretched hands. Prominent veins on the chest may imply obstruction 
of the superior vena cava. The patient''s face may reveal signs of anae­
mia, or there may be a Horner''s syndrome due to a Pancoast tumour.
Respiratory rate and rhythm may be altered; the normal respi­
ratory rate is 14-16 breaths per minute. Tachypnoea is an increased 
respiratory rate. Apnoea is the absence of breathing; some patients 
have episodes of apnoea during sleep.
Hands should be inspected for evidence of tobacco staining on 
the fingers, clubbing or a fine tremor (Box 28.6).
Cyanosis (see p. 1030) is a dusky discoloration of the skin and 
mucous membranes, due to the presence of more than 50 g/L of 
desaturated haemoglobin. When it has a central cause, cyanosis 
is visible on the tongue (especially the underside) and lips. Patients 
with central cyanosis will also be cyanosed peripherally. Peripheral 
cyanosis without central cyanosis is caused by a reduced peripheral 
circulation and is noted on the fingernails and skin of the extremi­
ties, with associated coolness of the skin.
Finger clubbing is present when the normal angle between the 
base of the nail and the nail fold is lost (Fig. 28.9). The base of 
the nail is fluctuant owing to increased vascularity, and there is an 
increased curvature of the nail in all directions, with expansion of 
the end of the digit. Some causes of clubbing are given in Box 28.7. 
Clubbing is not a feature of uncomplicated COPD. 
Palpation and percussion
The position of the trachea and apex beat should be checked. The 
supraclavicular fossa, cervical chains and axilla are examined for 
enlarged lymph nodes. The distance between the sternal notch and 
Acute
 • Airways obstruction
 • Anaphylaxis
 • Asthma
 • Pneumothorax
 • Pulmonary embolus
 • Myocardial infarction
 • Pulmonary oedema
 • Arrhythmias
 • Anxiety 
Subacute
 • Pneumonia
 • Exacerbation of COPD
 • Angina
 • Cardiac tamponade
 • Metabolic acidosis
 • Pain
 • Pontine haemorrhage 
Chronic
 • COPD
 • Pleural effusion
 • Malignancy
 • Chronic pulmonary emboli
 • Restrictive lung disorders
 • Congestive cardiac failure
 • Valvular dysfunction
 • Cardiomyopathy
 • Anaemia
 • Neuromuscular disorders
 • Deconditioning
   
COPD, chronic obstructive pulmonary disease.
Box 28.4 Causes of breathlessness
 1. Not troubled by breathlessness, except on strenuous exercise
 2. Short of breath when hurrying or walking up a slight hill
 3. Walks slower than contemporaries on the level because of breathless­
ness, or has to stop for breath when walking at own pace
 4. Stops for breath after about 100 m or after a few minutes on the level
 5. Too breathless to leave the house, or breathless when dressing or undressing
Box 28.5 Medical Research Council grading of dyspnoea 
(breathlessness scale)
 • Clubbing
 • Pallor
 • Warm, well-­perfused palms (CO2 retention)
 • Cyanosis
 • Flap
 • Tremor
 • Tobacco staining
 • Bruising and/or thin skin
 • Pulse rate and character
Box 28.6 Signs to look for in the hands', 5909),
   ('09751a96-d78d-518f-95bc-a1aa897c9522', 'KUMAR_CLARK_10_2017', 'KC-C28', 938, 956, 0, '28
938  Respiratory disease 
the cricoid cartilage (3-4 finger-­breadths in full expiration) is reduced 
in patients with severe airflow limitation. Chest expansion should 
be checked; a tape measure may be used if precise or serial mea­
surements are needed, such as in ankylosing spondylitis. Local 
discomfort over the sternochondral joints suggests costochondritis. 
In rib fractures, compression of the chest laterally and anteroposte­
riorly produces localized pain. On percussion, liver dullness is usu­
ally detected anteriorly at the level of the sixth rib. Liver and cardiac 
dullness disappear when the lungs are over-­inflated (Box 28.8). 
Auscultation
The patient is asked to take deep breaths through the mouth. Inspi­
ration should be more prolonged than expiration. Normal breath 
sounds are caused by turbulent flow in the larynx and sound 
harsher anteriorly over the upper lobes (particularly on the right). 
Healthy lungs filter out most of the high-­frequency component, and 
the resulting sounds are called vesicular.
If the lung is consolidated or collapsed, the high-­frequency hiss­
ing components of breath are not attenuated and can be heard as 
''bronchial breathing''. Similar sounds may be heard over areas of 
localized fibrosis or bronchiectasis. Bronchial breathing is accom­
panied by whispering pectoriloquy (whispered, high-­pitched sounds 
can be heard distinctly through a stethoscope). 
Added sounds
Wheeze. Wheeze results from vibrations in the collapsible part of the 
airways when the large and medium-­sized bronchi become constricted. 
It is usually heard during expiration and is commonly, but not invariably, 
present in asthma and COPD. In acute severe asthma, wheeze may 
not be heard, as airflow may be insufficient to generate the sound. 
Wheezes may be monophonic (single large airway obstruction) or poly­
phonic (narrowing of many small airways). An end-­inspiratory wheeze 
or ''squeak'' may be heard in obliterative bronchiolitis.
Crackles. These brief crackling sounds are probably produced 
by opening of previously closed bronchioles; early inspiratory crack­
les are associated with diffuse airflow limitation, while late inspi­
ratory crackles are characteristically heard in pulmonary oedema, 
lung fibrosis and bronchiectasis.
Pleural rub. This creaking or groaning sound is usually well 
localized (said to sound like a foot crunching through fresh-­fallen 
snow). It indicates inflammation and roughening of the pleural sur­
faces, which normally glide silently over one another, and is heard in 
association with lung infections and consolidation.
Respiratory
 • Bronchial carcinoma, including hypertrophic pulmonary osteoarthropathy
 • Chronic suppurative lung disease:
 
- Bronchiectasis
 
- Lung abscess
 
- Empyema
 • Idiopathic lung fibrosis
 • Pleural and mediastinal tumours (e.g. mesothelioma)
 • Cryptogenic organizing pneumonia 
Cardiovascular
 • Cyanotic heart disease
 • Subacute infective endocarditis
 • Atrial myxoma 
Miscellaneous
 • Congenital - no disease
 • Cirrhosis
 • Inflammatory bowel disease
 • Thyroid acropachy
Box 28.7 Some causes of finger clubbing
Pathological process
Mediastinal displacement
Percussion note
Breath sounds
Vocal resonance
Added sounds
Consolidation (i.e. lobar 
pneumonia)
None
Dull
Bronchial
Increased
Fine crackles
Collapse
Major bronchus
Towards lesion
Dull
Diminished or absent
Reduced or absent
None
Peripheral bronchus
Towards lesion
Dull
Bronchial
Increased
Fine crackles
Fibrosis
Localized
Towards lesion
Dull
Bronchial
Increased
Coarse crackles
Generalized (e.g. 
idiopathic lung fibrosis)
None
Normal
Vesicular
Increased
Fine crackles
Pleural effusion 
(>500 mL)
Away from lesion (in 
massive effusion)
Stony dull
Vesicular reduced or 
absent
Reduced or absent
None
Large pneumothorax
Away from lesion
Normal or hyper-­
resonant
Reduced or absent
Reduced or absent
None
Asthma
None
Normal
Vesicular
Prolonged expiration
Normal
Expiratory polyphonic 
wheeze
Chronic obstructive 
pulmonary disease
None
Normal
Vesicular
Prolonged expiration
Normal
Expiratory polyphonic 
wheeze and coarse 
crackles
Bronchiectasis
None
Normal
Vesicular
Normal
Coarse crackles
Box 28.8 Physical signs of respiratory disease
Fig. 28.9  Clubbing deformity.  The finger on the right is clubbed 
compared with the normal-­shaped finger on the left. (From Hochberg 
MC, Gravallese EM, Silman AJ et al. Rheumatology, 7th edn. Elsevier 
Inc.; 2019; Fig. 213.2.)', 4470),
   ('69073a1b-0a66-5abf-8f7e-33ce2786ec8b', 'KUMAR_CLARK_10_2017', 'KC-C28', 939, 957, 0, '28
Clinical Approach to the Patient with Respiratory Disease  939
Vocal resonance. Healthy lung attenuates high-­frequency 
notes, as compared to the lower-­pitched components of speech. 
Consolidated lung has the reverse effect, transmitting high frequen­
cies well; the spoken word then takes on a bleating quality. Whis­
pered (and therefore high-­pitched) speech can be clearly heard over 
consolidated areas, as compared to healthy lung. Low-­frequency 
sounds such as ''ninety-­nine'' are well transmitted across healthy 
lung to produce vibration that can be felt over the chest wall. Con­
solidated lung transmits these low-­frequency noises less well, and 
pleural fluid severely dampens or obliterates the vibrations alto­
gether. Tactile vocal fremitus is the palpation of this vibration, usually 
by placing the edge of the hand on the chest wall. For all practical 
purposes, this duplicates the assessment of vocal resonance and is 
not routinely performed as part of the chest examination. 
Cardiovascular system examination
This gives additional information about the lungs (see p. 1029). 
Additional bedside tests
Review the patient''s observation chart, particularly oxygen satura­
tions and the concentration of additional oxygen that the patient may 
be receiving. Inspect any sputum pots. Since so many patients with 
respiratory disease have airflow limitation, airflow should be routinely 
measured using a peak flow meter or spirometer. This is a much more 
useful assessment of airflow limitation than any physical sign. 
Investigation of respiratory disease
Imaging
Imaging is essential in the investigation of most chest symptoms. Some 
diseases, such as tuberculosis or lung cancer, may be undetectable 
on clinical examination but may be obvious on the chest X-­ray. Con­
versely, asthma or chronic bronchitis may be associated with a normal 
chest X-­ray. Always try to obtain previous images for comparison.
Chest X-­ray
See Box 28.9 and Fig. 28.1.
Collapse and consolidation
Simple pneumonia is easy to recognize (see Fig. 28.28) but a care­
ful search should be made for any evidence of collapse (Fig. 28.10 
and Box 28.10). Loss of volume or crowding of the ribs is the best 
indicator of lobar collapse. The lung lobes collapse in characteristic 
directions:
 • The lower lobes collapse downwards and towards the mediasti­
num.
 • The left upper lobe collapses forwards against the anterior chest 
wall.
 • The right upper lobe collapses upwards and inwards, giving the 
appearance of an arch over the remaining lung.
 • The right middle lobe collapses anteriorly and inwards, obscur­
ing the right heart border.
 • If a whole lung collapses, the mediastinum will shift towards the 
side of the collapse.
Uncomplicated consolidation does not cause mediastinal shift 
or loss of lung volume, and so any of these features should raise the 
suspicion of an endobronchial obstruction. 
Pleural effusion
Pleural effusions (see Fig. 28.31) need to be larger than 500 mL 
to cause much more than blunting of the costophrenic angle. On 
an erect film, they produce a characteristic shadow with a curved 
upper edge rising into the axilla. If they are very large, the whole of 
one hemithorax may be opaque, with mediastinal shift away from 
the effusion. 
Check
 • Centring of the image. The distance between each clavicular head and 
the spinal processes should be equal.
 • Penetration. Make sure the image is not too dark and adjust the 
­contrast.
 • View:
 
- Postero-­anterior (PA) views are used for routine images; the X-­ray 
source is behind the patient.
 
- Anteroposterior (AP) views are used only in patients who are unable 
to stand or cannot be taken to the radiology department; the cardiac 
outline appears bigger and the scapulae cannot be moved out of the 
way.
 
- Lateral views were used to localize pathology but have been replaced 
by CT scans. 
Look at
 • Shape and bony structure of the chest wall
 • Centrality of the trachea
 • Elevation/flatness of the diaphragm
 • Shape, size and position of the heart
 • Shape and size of the hilar shadows
 • Shape and size of any lung abnormalities
 • Vascular shadowing
Box 28.9 The chest X-­ray
7UDFKHD
GHYLDWHG
WRWKHOHIW
+HDUWDQG
DSH[EHDW
GHYLDWHGWR
WKHOHIW
Fig. 28.10  Collapse of the left upper lobe.  Chest X-­ray showing 
increased opacification in the left upper and mid zone with evidence 
of left-­sided volume loss.
 • Enlarged tracheobronchial lymph nodes due to malignant disease or 
tuberculosis
 • Inhaled foreign bodies (e.g. peanuts) in children, usually in the right main 
bronchus
 • Bronchial casts or plugs (e.g. allergic bronchopulmonary aspergillosis)
 • Retained secretions postoperatively and in debilitated patients
Box 28.10 Causes of lung collapse', 4795),
   ('9157d331-d566-5437-a012-f073fb2dc16b', 'KUMAR_CLARK_10_2017', 'KC-C28', 940, 958, 0, '28
940  Respiratory disease 
Fibrosis
Localized fibrosis produces streaky shadowing, and the accompa­
nying loss of lung volume causes mediastinal structures to move to 
the same side. More generalized fibrosis can lead to a honeycomb 
appearance (see p. 988), seen as diffuse shadows containing mul­
tiple circular translucencies a few millimetres in diameter. 
Round shadows
Lung cancer is the most common cause of large round shadows but 
many other aetiologies are recognized (Box 28.11). 
Miliary mottling
This term, derived from the Latin for millet, describes numerous min­
ute opacities, 1-3 mm in size. The most common causes are tubercu­
losis, pneumoconiosis, sarcoidosis, idiopathic pulmonary fibrosis and 
pulmonary oedema (see Fig. 30.15), although pulmonary oedema is 
usually perihilar and accompanied by larger, fluffy shadows. Pulmo­
nary microlithiasis is a rare but striking cause of miliary mottling. 
Computed tomography
Computed tomography (CT) provides excellent images of the lungs 
and mediastinal structures (Fig. 28.11). It is essential in staging bron­
chial carcinoma by demonstrating tumour size, nodal involvement, 
metastases and invasion of mediastinum, pleura or chest wall. CT-­
guided needle biopsy allows samples to be obtained from periph­
eral masses. Staging scans should assess liver and adrenals, which 
are common sites for metastatic disease. Mediastinal structures are 
shown more clearly after injecting intravenous contrast medium.
High-­resolution CT (HRCT) samples lung parenchyma with 
1-2 mm thickness scans at 10-20 mm intervals and is used to assess 
diffuse inflammatory and infective parenchymal processes. HRCT 
scanning does not require any intravenous contrast. It is valuable in:
 • evaluation of diffuse disease of the lung parenchyma, includ­
ing sarcoidosis, hypersensitivity pneumonitis, occupational lung 
disease and any other form of interstitial pulmonary fibrosis
 • diagnosis of bronchiectasis, having a sensitivity and specificity 
of >90%
 • distinction of emphysema from diffuse parenchymal lung dis­
ease or pulmonary vascular disease as a cause of a low gas 
transfer factor with otherwise normal lung function
 • suspected opportunistic lung infection in immunocompromised 
patients
 • diagnosis of lymphangitis carcinomatosa.
Multi-­slice CT scanners can produce detailed images in two or 
three dimensions in any plane. This detail is particularly useful for 
the detection of pulmonary emboli. Pulmonary nodules and airway 
disease are more easily defined, reducing the need for HRCT.
CT pulmonary angiography (CTPA) is used to investigate for 
pulmonary embolism and enables visualization of the pulmonary 
 • Carcinoma
 • Metastatic tumours (usually multiple shadows)
 • Lung abscess (usually with fluid level)
 • Encysted interlobar effusion (usually in horizontal fissure)
 • Hydatid cysts (often with a fluid level)
 • Arteriovenous malformations (usually adjacent to a vascular shadow)
 • Aspergilloma
 • Rheumatoid nodules
 • Tuberculoma (may be calcification within the lesion)
 • Bronchial carcinoid
 • Cylindroma
 • Chondroma
 • Lipoma 
Other shadows related to mediastinum
 • Pericardium
 • Oesophagus 
Can be characterised by performing a lateral chest X-ray
 • Spinal cord
Box 28.11 Causes of round shadows (>3 cm) in the lung








$
%
&










Fig. 28.11  Computed tomography scans of the lung.  (A) Axial 
CT image of the thorax on lung settings. (1) Right hilum; (2) left hilum; 
(3) right main bronchus; (4) left main bronchus; (5) right lung; (6) left 
lung; (7) bronchus; (8) blood vessel. (B) Axial CT image of the thorax 
on soft tissue settings. (1) Right lung; (2) left lung; (3) ascending aorta; 
(4) descending aorta; (5) pulmonary trunk; (6) right pulmonary artery; 
(7) left pulmonary artery; (8) vertebra; (9) rib; (10) scapula. (C) CT 
chest demonstrates a right upper lobe carcinoma that is invading the 
mediastinum (black arrow) and prominent mediastinal lymph nodes 
(white arrow).', 4040),
   ('ee58ea02-768a-5685-9b1a-00a222afc2a9', 'KUMAR_CLARK_10_2017', 'KC-C28', 941, 959, 0, '28
Clinical Approach to the Patient with Respiratory Disease  941
arteries. Contrast is injected and images are taken in timed fashion, 
so that the contrast agent is in the pulmonary circulation. 
Magnetic resonance imaging
Magnetic resonance imaging (MRI) with electrocardiography (ECG) 
gating allows accurate imaging of the heart and aortic aneurysms. 
MRI has been used in staging lung cancer and assessing tumour 
invasion in the mediastinum and chest wall and at the lung apex 
because it produces good images in the sagittal and coronal planes. 
Vascular structures can be clearly differentiated, as flowing blood 
produces a signal void on MRI. Traditionally, MRI has been less use­
ful than CT in parenchymal lung disease; however, it may have a 
place in interstitial lung disease assessment in the future. 
Positron emission tomography-computed 
tomography
PET-­CT combines a CT scan and positron emission tomography. 
Positron-­emitting isotopes such as 18fluorodeoxyglucose (18FDG) 
are used as contrast and are taken up rapidly by metabolically active 
tissue such as lung cancers. PET imaging is used for lung cancer 
staging prior to curative treatment such as surgery or radiotherapy. 
FDG-­PET can also be useful in determining an appropriate site for a 
biopsy and can often assist with differentiating benign from malig­
nant tumours; however, inflammatory lesions may also be FDG-­avid. 
Scintigraphic imaging
Isotopic lung scans were widely used for the detection of pulmonary 
emboli but are now performed less often, owing to the widespread 
use of CTPA. They are discussed in more detail on page 1005. 
Ultrasound
Two-­dimensional transthoracic ultrasound is a technique used for 
assessing a pleural effusion. Ultrasound confirms the presence of 
pleural fluid and provides details about the nature of the effusion, 
such as whether it is a simple pleural effusion (single collection), 
heavily loculated with adhesions or organized (more gelatinous). 
Ultrasound assists in determining the best site for aspiration and it 
is recommended that any invasive pleural procedure, such as pleu­
ral aspiration and intercostal chest drain placement, is performed 
with ultrasound screening. Ultrasound-­guided biopsy is used for 
lung masses that abut the pleura or pleural masses, if appropriate. 
It is also used in bronchoscopy (endobronchial ultrasound, EBUS) 
to stage and sample mediastinal lymph nodes (see p. 944). 
Respiratory function tests
In clinical practice, airflow limitation can be assessed by relatively 
simple tests that have good intra-­subject repeatability (Box 28.12). 
Results must be compared with predicted values for healthy sub­
jects, as normal ranges vary with sex, age, height and ethnic group. 
Moreover, there is considerable variation between healthy individu­
als of the same size and age; the standard deviation for the PEFR 
is approximately 50 L/min, and for the FEV1 approximately 0.4 L. 
Repeated measurements of lung function are useful for assessing 
the progression of disease in individual patients.
Tests of ventilatory function
These tests are used mainly to assess the degree of airflow limita­
tion during expiration.
Spirometry
The patient takes a maximum inspiration followed by a forced expi­
ration (for as long as possible) into the spirometer. The spirometer 
measures the 1-­second forced expiratory volume (FEV1) and the 
total volume of exhaled gas (forced vital capacity, FVC). Both FEV1 
and FVC are related to height, age, sex and ethnicity, and help to 
differentiate between an obstructive and a restrictive pattern of 
respiratory compromise (Fig. 28.12; Box 28.13).
In chronic airflow limitation (particularly COPD and asthma), the 
total lung capacity (TLC) is usually increased, yet there is nearly 
always some reduction in the FVC. This is because collapse of small 
Test
Use
Advantages
Disadvantages
PEFR
Monitoring changes in airflow limitation in 
asthma
Portable
Can be used at the bedside
Effort-­dependent
Poor measure of chronic airflow 
limitation
FEV, FVC, FEV1/FVC
Assessment of airflow limitation
(the best single test)
Reproducible
Relatively effort-­independent
Bulky equipment but smaller 
­portable machines available
Flow-volume curves
Assessment of flow at lower lung volumes
Detection of large-­airway obstruction, both 
intra-­ and extrathoracic (e.g. tracheal 
stenosis, tumour)
Recognizes patterns of flow-volume 
curves for different diseases
Sophisticated equipment needed 
for full test but expiratory 
loop possible with compact 
spirometry
Airways resistance
Assessment of airflow limitation
Sensitive
Technique difficult to perform
Lung volumes
Differentiation between restrictive and 
obstructive lung disease
Effort-­independent, complements FEV1
Sophisticated equipment needed
Gas transfer
Assessment and monitoring of extent of 
interstitial lung disease and emphysema
Non-­invasive (compared with lung 
biopsy or radiation from repeated 
chest X-­rays and CT)
Sophisticated equipment needed
Blood gases
Assessment of respiratory failure
Can detect early lung disease when 
measured during exercise
Invasive
Pulse oximetry
Postoperative, sleep studies and respiratory 
failure
Continuous monitoring
Non-­invasive
Measures saturation only
Exercise tests (6-­min 
walk)
Practical assessment for disability and 
effects of therapy
No equipment required
Time-­consuming
Learning effect
At least two walks required
Cardiorespiratory 
assessment
Early detection of lung/heart disease
Fitness assessment
Differentiates breathlessness due to 
lung or heart disease
Expensive and complicated 
­equipment required
Box 28.12 Respiratory function and exercise tests
CT, computed tomography; FEV, forced expiratory volume; FEV1, forced expiratory volume in 1 sec; FVC, forced vital capacity; PEFR, peak expiratory flow rate.', 5833),
   ('d6aa0acc-9a21-55d1-b9dc-cd8b85280162', 'KUMAR_CLARK_10_2017', 'KC-C28', 942, 960, 0, '28
942  Respiratory disease 
airways causes obstruction to airflow before the normal residual 
volume (RV) is reached. This trapping of air within the lung is a char­
acteristic feature of these diseases. 
Peak expiratory flow rate
Peak expiratory flow rate (PEFR) is an extremely simple and cheap 
test. Subjects take a full inspiration to total lung capacity and then 
blow out forcefully into the peak flow meter (Fig. 28.13). The best of 
three attempts is recorded.
Although reproducible, PEFR is mainly dependent on the flow 
rate in larger airways and it may be falsely reassuring in patients 
with moderate airflow limitation. PEFR is mainly used to diagnose 
asthma, and to monitor exacerbations of asthma and response to 
treatment. Regular measurements of peak flow rates on waking, 
during the afternoon and before going to bed demonstrate the wide 
diurnal variations in airflow limitation that characterize asthma and 
allow objective assessment of response to treatment (Fig. 28.14). 
Other ventilatory function tests
Measurement of airways resistance in a body box (plethysmograph) 
is more sensitive but the equipment is expensive and the neces­
sary manoeuvres are too exhausting for many patients with chronic 
airflow limitation. 
Flow-volume loops
Plotting flow rates against expired volume (flow-volume loops, see 
Fig. 28.6) shows the site of airflow limitation within the lung. At the 
start of expiration from TLC, maximum resistance is from the large 
airways, and this affects the flow rate for the first 25% of the curve. 
As air is exhaled, lung volume reduces and the flow rate becomes 
dependent on the resistance of smaller airways. In COPD, which 
mainly affects the smaller airways, expiratory flow rates at 50% or 
25% of the vital capacity are disproportionately reduced when com­
pared with flow rates at larger lung volumes. Flow-volume loops 
also show obstruction of large airways: for example, tracheal nar­
rowing due to tumour or retrosternal goitre. 






     












7LPHV
1RUPDO
5HVWULFWLYHSDWWHUQ
/
/
\HDUV
\HDUV
\HDUV
)(9
)9&
7LPHV
)(9
)(9
)9&
)9&






     
7LPHV
/
$LUIORZOLPLWDWLRQ
$
%
&
Fig. 28.12  Spirometry: volume-time curves.  (A) Normal patterns 
for age and sex. (B) Restrictive pattern (FEV1 and FVC reduced). (C) 
Airflow limitation (FEV1 only reduced). FEV1, forced expiratory volume 
in 1 sec; FVC, forced vital capacity.
0HQ






















:RPHQ
3()5/PLQ
+HLJKWFP
3HDNIORZPHWHU
*UDSKRIQRUPDOUHDGLQJV
$JH\HDUV






$
%
Fig. 28.13  Peak flow measurements.  (A) Peak flow meter; the lips should be tight around the mouth­
piece. (B) Normal readings. PEFR, peak expiratory flow rate.
 • Normal: approximately 75%
 • Airflow obstruction: reduced
 • Restriction: normal or increased
 
FEV1, forced expiratory volume in 1 second; FVC, forced vital capacity.
Box 28.13 FEV1/FVC ratio', 3031),
   ('c0e1894a-c255-5e5d-8b55-9b4539f101cb', 'KUMAR_CLARK_10_2017', 'KC-C28', 943, 961, 0, '28
Clinical Approach to the Patient with Respiratory Disease  943
Lung volumes
The subdivisions of lung volume are shown in Fig. 28.15. Tidal vol­
ume and vital capacity can be measured using a simple spirometer 
but alternative techniques are needed to measure TLC and RV. TLC 
is measured by inhaling air containing a known concentration of 
helium and measuring its dilution in the exhaled air. RV can be cal­
culated by subtracting the vital capacity from the TLC.
TLC measurements using this technique are inaccurate if there 
are large cystic spaces in the lung because helium cannot diffuse into 
them. Under these circumstances the thoracic gas volume can be 
measured more accurately using a body plethysmograph (see earlier). 
The difference between measurements made by these two methods 
shows the extent of non-­communicating air space within the lungs. 
Transfer factor
In normal lungs the transfer factor accurately reflects how efficiently 
oxygen diffuses from alveolar air into blood, and depends on the 
thickness of the alveolar-capillary membrane. In lung disease the dif­
fusing capacity (DCO) is also affected by the ventilation-perfusion rela­
tionship. Carbon monoxide is used as a surrogate marker to measure 
this, as it has a similar diffusion rate to oxygen. A low concentration of 
carbon monoxide is inhaled and the rate of absorption calculated. To 
control for differences in lung volume, the uptake of carbon monoxide 
is expressed relative to lung volume as a transfer coefficient (KCO).
Gas transfer is reduced in patients with severe degrees of 
emphysema and fibrosis, but also in heart failure and anaemia. 
Although relatively non-­specific, gas transfer is particularly useful in 
the detection and monitoring of diseases affecting the lung paren­
chyma (e.g. idiopathic pulmonary fibrosis, sarcoidosis and asbesto­
sis). The KCO is raised in pulmonary haemorrhage.
Peripheral oxygen saturation (SpO2) can be continuously 
measured using an oximeter with either ear or finger probes. Pulse 
oximetry has become an essential part of the routine monitoring of 
patients in hospital and clinics. It is also useful in exercise testing 
and reduces the need to measure arterial blood gases. 
Measurement of blood gases
This technique is described on page 225, where a guide to interpret­
ing blood gas analyses is provided.
Measurement of the partial pressures of oxygen and carbon 
dioxide in arterial blood is essential in managing respiratory failure, 
when repeated measurements are often the best guide to therapy. 
Exhaled nitric oxide
Nitric oxide (NO) is produced by the bronchial epithelium and 
increases in asthma and other forms of airway inflammation. Mea­
suring exhaled NO can guide therapy in asthma that is difficult to 
control (see p. 951). 
Six-­minute walk test
In this validated test the distance walked in metres is recorded over 
a period of 6 minutes. The oxygen saturations, pulse rate and dis­
tance are measured. 
Cardiopulmonary exercise testing
This provides a functional assessment of cardiopulmonary reserve 
and provides information about cardiorespiratory and metabolic 
muscle function. It is usually performed on a treadmill or a cycle 
ergometer. Oxygen consumption, carbon dioxide production and 
ventilation can be calculated.
Indications include the investigation of unexplained breathless­
ness, establishing prognosis in respiratory illnesses and predicting 
risk in perioperative assessment. 
Nocturnal polygraphy
This multichannel sleep study records pulse, oxygen saturation, 
nasal flow, body position, and thoracic and abdominal wall move­
ments. It is useful in the investigation of sleep-­disordered breathing. 
Haematological and biochemical tests
It is useful to measure:
 • haemoglobin: to detect anaemia or polycythaemia
 • packed cell volume: as secondary polycythaemia occurs with 
chronic hypoxia
 • routine biochemistry: often disturbed in lung cancer and infection
 • D-­dimer: to detect intravascular coagulation; a negative test 
makes pulmonary embolism very unlikely.
Other blood investigations sometimes required include α1-­
antitrypsin levels, Aspergillus antibodies, viral and mycoplasma 
serology, autoantibody profiles and specific IgE measurements. 
Sputum
Sputum should be inspected for colour:
 • Yellowish green indicates inflammation (infection or allergy).
 • Blood suggests bronchiectasis, lung cancer (see p. 976) or pul­
monary infarction.






''D\
3()5/PLQ














01(
01(
3UHGQLVRORQHPJ
        
Fig. 28.14  Diurnal variability in peak expiratory flow rate (PEFR) in 
asthma, showing the effect of steroids.  MNE, morning, noon, evening.
 7RWDOOXQJFDSDFLW\
 ,QVSLUDWRU\UHVHUYHYROXPH
 7LGDOYROXPH






 )XQFWLRQDOUHVLGXDOFDSDFLW\
 9LWDOFDSDFLW\
 5HVLGXDOYROXPH
Fig. 28.15  The subdivisions of the lung volume.', 4941),
   ('d35424b1-1be7-5b6b-85a3-9869bbe201d2', 'KUMAR_CLARK_10_2017', 'KC-C28', 944, 962, 0, '28
944  Respiratory disease 
Microbiological studies (e.g. Gram stain and culture) are rarely 
helpful in upper respiratory tract infections or in acute or chronic 
bronchitis. Conversely, they are of value in:
 • pneumonia
 • tuberculosis (a specific request to test for acid-­fast bacilli (AFB) 
is required)
 • bronchiectasis.
Sputum cytology
This may be an adjunct in the management of asthma but is more 
often used in research studies. Its advantages are its speed, cheap­
ness and non-­invasive nature. A reliable cytologist is needed. Spu­
tum can be induced by inhalation of nebulized hypertonic saline 
(5%). Better samples can be obtained by bronchoscopy and bron­
chial washings (see later). 
Pleural aspiration
Diagnostic aspiration may be necessary to determine the aetiol­
ogy of a pleural effusion, especially if unilateral. This is usually 
done under ultrasound guidance, using full aseptic precautions. 
A needle is inserted under local anaesthesia through an intercos­
tal space towards the top of the area identified on ultrasound. 
Fluid is withdrawn and the presence of any blood is noted. 
Samples are sent for cytology and biochemical analysis (pro­
tein estimation, lactate dehydrogenase (LDH) and bacteriologi­
cal examination, including culture and Ziehl-Neelsen/auramine 
staining for tuberculosis). A therapeutic aspiration can be per­
formed in the context of a large pleural effusion to help relieve 
extreme breathlessness. 
Pleural biopsy
A pleural biopsy may be a necessary part of the investigation of a 
unilateral exudative pleural effusion or suspicious pleural thicken­
ing. Pleural biopsies may be obtained with CT or ultrasound guid­
ance. An alternative means by which to obtain a pleural biopsy is 
video-­assisted thoracoscopy (VATS). A scope is introduced into the 
pleural space, allowing direct visualization and biopsy of the parietal 
pleura. A pleural effusion can be drained during this procedure. 
Intercostal drain placement
An intercostal chest drain is an indwelling drain that is placed in 
the pleural space using ultrasound guidance (Box 28.14). It is con­
nected to an underwater seal bottle. Circumstances in which a 
chest drain is placed include:
 • pneumothorax
 • large pleural effusion
 • empyema.
Occasionally, a long-­term pleural drain may be needed for recur­
rent effusions. 
Fibreoptic bronchoscopy
This endoscopic procedure allows direct visualization of the endo­
bronchial tree down to the subsegmental level (Fig. 28.16). The pro­
cedure is performed under local anaesthesia and sedation.
Indications for bronchoscopy (Box 28.15) are:
 • Visualization and biopsy of an endobronchial lesion (sus­
pected malignancy). An endobronchial biopsy may be taken.
 • Collapsed lung or lobe. Bronchoscopy is performed to deter­
mine the nature of the obstruction. Possible causes include an 
aspirated foreign body, a mucus plug (these may be removed 
during the bronchoscopy by suction, or by using forceps or a 
dormier basket) or endobronchial tumour (which may be biop­
sied). Airway patency may be restored by cryotherapy or laser 
therapy, and may be maintained if it is possible to place a stent.
 • Microbiological sampling in the context of unresolving infec­
tion or suspected tuberculosis. More distal lesions may be sam­
pled by washing or blind brushing.
 • Diagnosis of diffuse inflammatory and infective lung pro­
cesses by bronchoalveolar lavage and transbronchial biopsy. 
The yield is best in sarcoidosis, lymphangitis carcinomatosa and 
hypersensitivity pneumonitis. Other fibrotic lung diseases rarely 
yield diagnostic samples and so it may be preferable to perform 
open or thoracoscopic lung biopsy.
 • Performance of EBUS under local anaesthetic and sedation. 
A dedicated scope is used with an ultrasound probe at the 
distal end, which allows detailed visualization of the medias­
tinal nodes. The lymph nodes can be aspirated and samples 
sent for cytological and microbiological examination. EBUS 
is performed when CT imaging shows enlarged mediastinal 
lymph nodes, for which the differential diagnosis includes 
Explain the nature of the procedure to the patient and obtain written 
consent.
Technique
 1. Identify the site for aspiration (using ultrasound in most cases).
 2. Carefully sterilize the skin over the aspiration site.
 3. Anaesthetize the skin, muscle and pleura with 2% lidocaine.
 4. Make a small incision and insert an 8-12 French gauge drain, using 
the Seldinger technique. A needle is used to enter the pleural space and 
then withdrawn over a guidewire, over which the catheter is inserted. 
(A larger-­calibre catheter is needed for drainage of empyema, or a 28 
French gauge Argyle catheter.)
 5. Attach to a three-­way tap and 50 mL syringe, and aspirate up to 
1000 mL. Stop aspiration if the patient becomes uncomfortable; shock 
may ensue if too much fluid is withdrawn too quickly.
 6. If the drain is to stay in, secure it to skin with suture and sterile dressing.
 7. Attach the drain to an underwater seal drainage bottle and allow fluid 
to drain. Clamp the drain and release periodically, especially if patient 
becomes uncomfortable (usually up to 1000 mL at a time before clamp­
ing for a few hours).
 8. Perform a chest X-­ray to check the position of the drain. 
Pleurodesis
 1. Instil lidocaine 3 mg/kg and then talc 4-5 g in 50 mL sodium chloride 
0.9% solution into the pleural cavity to achieve pleurodesis in recurrent/
malignant effusion.
Box 28.14 Intercostal drainage
Fig. 28.16  Normal endobronchial appearances as seen at fibre­
optic bronchoscopy.', 5612),
   ('e80a56a4-bc36-544c-88bf-5e0d2b7e51ef', 'KUMAR_CLARK_10_2017', 'KC-C28', 945, 963, 0, '28
Diseases of the Upper Respiratory Tract  945
sarcoid, tuberculosis, lung cancer, lymphoma and metastatic 
diseases from other primary malignancies. 
Mediastinoscopy
This surgical procedure is performed under general anaesthetic. A 
rigid scope is passed from just above the sternum into the anterior 
mediastinum. Mediastinoscopy is used in the diagnosis of medi­
astinal masses and in the staging of nodal disease in carcinoma of 
the bronchus. It is needed much less often since the introduction 
of EBUS. 
Video-­assisted thoracoscopic lung biopsy
VATS lung biopsy has largely replaced open thoracotomy when a 
lung biopsy is required (see p. 988). 
Skin-­prick tests
Allergen solutions are placed on the skin (usually the volar surface 
of the forearm) and the epidermis is broken using a 1 mm tipped 
lancet. A separate lancet should be used for each allergen. If the 
patient is sensitive to the allergen, a weal develops. The weal diam­
eter is measured after 10 minutes. A weal of at least 3 mm diameter 
is regarded as positive, provided that the control test is negative. 
The results should always be interpreted in light of the history. Skin 
tests are not affected by bronchodilators or corticosteroids but anti­
histamines should be discontinued at least 48 hours before testing. 
Bronchial provocation testing
This is performed in a lung function laboratory and may be useful 
in the diagnosis of asthma. Airway hyper-­responsiveness (AHR) is a 
characteristic feature of asthma and can be demonstrated by ask­
ing patients to inhale gradually increasing concentrations of hista­
mine or methacholine (bronchial provocation tests). This induces 
transient airflow limitation in susceptible individuals (approximately 
20% of the population); the severity of AHR can be graded accord­
ing to the provocation dose (PD) or concentration (PC) of the agonist 
that produces a 20% fall in FEV1. Patients with clinical symptoms of 
asthma respond to very low doses of methacholine. AHR can also 
be assessed by exercise testing or inhalation of cold, dry air, man­
nitol or hypertonic saline.
Further reading
Bohadana A, Izbicki G, Kraman SS. Fundamentals of lung auscultation. N Engl 
J Med 2014; 370:744-751.
Ellis S. Interpreting Chest X-­rays. Banbury: Scion; 2010.
Hansell DM, Lynch DA, Page McAdams H et al. Imaging of Diseases of the 
Chest, 5th edn. Chicago: Elsevier Mosby; 2010. 
DISEASES OF THE UPPER 
RESPIRATORY TRACT
Rhinitis
Rhinitis is defined clinically as sneezing attacks, nasal discharge or 
blockage occurring for more than an hour on most days.
The common cold (acute coryza)
This highly infectious illness (see p. 519) is caused by a variety of 
respiratory viruses: for example, the rhinoviruses (most common), 
coronaviruses and adenoviruses. Infectivity from close personal 
contact (nasal mucus on hands) or droplets is high in the early 
stages of the infection. There are at least 100 different antigenic 
strains of rhinovirus, making it difficult for the immune system to 
confer protection. The incubation period varies from 12 hours to 
5 days.
The clinical features are tiredness, slight pyrexia, malaise, and 
a sore nose and pharynx. Sneezing and profuse, watery nasal dis­
charge are followed by thick mucopurulent secretions that may per­
sist for up to a week. Secondary bacterial infection occurs in only a 
minority of cases. 
Other forms of rhinitis
Rhinitis can be subdivided by the frequency with which symptoms 
occur:
 • for a limited period of the year (seasonal or intermittent rhinitis)
 • throughout the whole year (perennial or persistent rhinitis).
Seasonal rhinitis (intermittent)
This is the most common allergic disorder. It is often called ''hay­
fever'', but as this implies that only grass pollen is responsible it is 
better described as seasonal (or intermittent) allergic rhinitis. World­
wide prevalence varies from 2% to 20%. Prevalence is maximal in 
the second decade, and up to 30% of UK teenagers and young 
adults are affected each June and July.
Nasal irritation, sneezing and watery rhinorrhoea occur, but 
many also suffer from itching of the eyes and soft palate, and occa­
sionally even itching of the ears because of the common innervation 
of the pharyngeal mucosa and the ear. In addition, approximately 
20% suffer from seasonal wheezing. Common seasonal allergens 
include tree and grass pollens and mould spores.
Since the pollination patterns of plants that give rise to high pol­
len counts vary from country to country, seasonal rhinoconjunctivitis 
and accompanying wheeze may occur at different times of year in 
different regions. 
Perennial rhinitis (persistent)
In about 50% of patients with perennial rhinitis, symptoms of 
sneezing and watery rhinorrhoea predominate, while the other 
Informed written consent is obtained after the nature of the procedure is 
explained.
Indications
 • Lesions requiring biopsy seen on chest X-­ray
 • Haemoptysis
 • Stridor
 • Positive sputum cytology for malignant cells with no chest X-­ray 
abnormality
 • Collection of bronchial secretions for bacteriology, especially tuberculosis
 • Recurrent laryngeal nerve paralysis of unknown aetiology
 • Infiltrative lung disease (to obtain a transbronchial biopsy)
 • Investigation of collapsed lobes or segments and aspiration of mucus 
plugs 
Disadvantages
 • All patients require sedation to tolerate the procedure
 • Minor and transient cardiac dysrhythmias occur in up to 40% of patients 
on passage of the bronchoscope through the larynx. Monitoring is 
required
 • Oxygen supplementation is required in patients with PaO2 <8 kPa
 • Fibreoptic bronchoscopy should be performed with care in the very sick, 
and transbronchial biopsies avoided in ventilated patients owing to the 
increased risk of pneumothorax
 • Massive bleeding may occur after biopsy of vascular lesions or carcinoid 
tumours. Rigid bronchoscopy may be required to allow adequate access 
to the bleeding point for haemostasis
Box 28.15 Fibreoptic bronchoscopy', 6028),
   ('30c1fbf5-4714-56d3-bdda-1425b39f1e4c', 'KUMAR_CLARK_10_2017', 'KC-C28', 946, 964, 0, '28
946  Respiratory disease 
50% complain mostly of nasal blockage. The patient may lose the 
senses of smell and taste but rarely has eye or throat symptoms. 
Sinusitis occurs in about 50% of cases, due to mucosal swelling 
that obstructs drainage from the sinuses. Perennial rhinitis is most 
frequent in the second and third decades, decreasing with age, 
and can be divided into four main types.
Perennial allergic rhinitis
The most common cause is allergy to the faecal particles of the 
house-­dust mite, Dermatophagoides pteronyssinus or D. farinae, 
which may be found in dust throughout the house (Fig. 28.17). 
Mites live off desquamated human skin scales and the highest 
concentrations (4000 mites/g of surface dust) are found in human 
bedding. The next most common allergens come from domestic 
pets (especially cats) and are proteins derived from urine or saliva 
spread over the surface of the animal, as well as skin protein. 
Allergy to urinary protein from small mammals is a major cause of 
morbidity among laboratory workers. Industrial dust, vapours and 
fumes cause occupationally related perennial rhinitis more often 
than asthma.
The presence of perennial rhinitis makes the nose more reactive 
to non-­specific stimuli, such as cigarette smoke, washing powders, 
household detergents, strong perfumes and traffic fumes. Although 
patients often think they are allergic to these stimuli, these are irri­
tant responses and do not involve antibodies. 
Perennial non-­allergic rhinitis with eosinophilia
No extrinsic allergic cause can be identified, either on taking a his­
tory or testing the skin, but eosinophilic granulocytes are present 
in nasal secretions. Most of these patients are intolerant of aspirin/
non-­steroidal anti-­inflammatory drugs (NSAIDs). 
Vasomotor rhinitis
Patients with this type of perennial rhinitis have no demonstrable 
allergy or nasal eosinophilia. Watery secretions and nasal conges­
tion are triggered by, for example, cold air, smoke, perfume or news­
print, possibly because of an imbalance of the autonomic nerves 
controlling the erectile tissue (sinusoids) in the nasal mucosa. 
Nasal polyps
These are round, smooth, soft, semitranslucent, pale or yellow, 
glistening structures attached to the sinus mucosa by a relatively 
narrow stalk or pedicle, occurring in patients with allergic or vaso­
motor rhinitis. The mechanism(s) of their formation is not known. 
They contain mast cells, eosinophils and mononuclear cells in large 
numbers and cause nasal obstruction, loss of smell and taste, and 
mouth breathing, but rarely sneezing, since the mucosa of the polyp 
is largely denervated. 
Investigations and diagnosis
The allergic factors causing rhinitis can usually be identified from the 
history. Skin-­prick testing is used to support the history. A positive 
test does not necessarily mean that an allergen causes the respira­
tory disease. However, if there is a compatible clinical history, it is 
more likely to be relevant. Allergen-­specific IgE antibodies can be 
measured in blood but such tests are much more expensive than 
skin tests and should be used only in patients who cannot be skin-­
tested for some reason (e.g. dermatographism, active eczema or 
inability to stop antihistamines for 3 days before skin tests). 
Management
Allergen avoidance
Removal of a household pet or total enclosure of industrial processes 
releasing sensitizing agents can lead to cure of rhinitis and, indeed, 
asthma. However, pollen avoidance is impossible. Contact may be 
diminished by wearing sunglasses, driving with the car windows shut, 
avoiding walks in the countryside (particularly in the late afternoon, 
when the number of pollen grains is highest at ground level) and keeping 
bedroom windows shut at night. These measures are rarely sufficient in 
themselves to control symptoms. Exposure to pollen is generally lower 
in coastal regions, where sea breezes carry pollen grains inland.
Exposure to mite allergen can be reduced by enclosing bedding 
in fabric specifically designed to prevent its passage, while allowing 
water vapour through. This is comfortable and also reduces symp­
toms. Acaricides (substances toxic to mites) are less effective and 
cannot be recommended. Increased room ventilation and reduced 
soft furnishings, including carpets, curtains and soft toys, can all 
help to reduce the mite load. 
H1 antihistamines
Antihistamines remain the most common therapy for rhinitis; in the UK 
most can be purchased directly over the counter. They are particu­
larly effective against sneezing and itching of the eyes and palate, but 
are less effective against rhinorrhoea and have little influence on nasal 
blockage. First-­generation antihistamines (chlorphenamine, hydroxy­
zine) cause sedation and loss of concentration in all patients (including 
those who are not aware of the problem) and should no longer be used. 
Second-­generation drugs, such as loratadine (10 mg once daily), des­
loratadine (5 mg daily), cetirizine (10 mg daily) and fexofenadine (120 mg 
daily), are at least as potent and do not cause sedation. 
Decongestants
Drugs with sympathomimetic activity (α-­adrenergic agents) are 
widely used to treat nasal obstruction. They may be taken orally 
µP
µP
µP
µP
+RXVHGXVWPLWHDQGIDHFHV
3ROOHQJUDLQV
''RPHVWLFSHWV
0RXOGV
Fig. 28.17  Common allergens causing allergic rhinitis and 
asthma.  These include the house-­dust mite, faeces of house-­dust 
mites, pollen grains, domestic pets and moulds. Percentages indicate 
the proportion of positive skin-­prick tests to these allergens in patients 
with allergic rhinitis.', 5677),
   ('517fa133-9167-577c-87af-faf85400d5f6', 'KUMAR_CLARK_10_2017', 'KC-C28', 947, 965, 0, '28
Diseases of the Upper Respiratory Tract  947
or, more commonly, as nasal drops or sprays (e.g. ephedrine nasal 
drops). Xylometazoline and oxymetazoline are widely used because 
they have a prolonged action and tachyphylaxis does not develop. 
Secondary nasal hyperaemia can occur some hours later as a 
rebound effect and rhinitis medicamentosa can develop if patients 
take increasing quantities of decongestant to overcome this phe­
nomenon. Although local decongestants are an effective treatment 
for vasomotor rhinitis, patients must be warned about rebound 
nasal obstruction and should use the drugs carefully. Ideally, such 
preparations should be prescribed for only a limited period to open 
the nasal airways and allow better access for other local therapy, 
such as topical corticosteroids. 
Anti-­inflammatory drugs
Sodium cromoglicate and nedocromil sodium act by blocking an 
intracellular chloride channel and influence mast cell and eosino­
phil activation and nerve function. Topical sodium cromoglicate and 
nedocromil sodium can be very effective in allergic conjunctivitis but 
are of limited value in allergic rhinitis. 
Corticosteroids
The most effective treatment for rhinitis is a topical corticosteroid 
preparation (e.g. beclometasone, fluticasone propionate, flutica­
sone furoate or mometasone furoate spray). Topical steroids should 
be started before the beginning of seasonal symptoms. The combi­
nation of a topical corticosteroid with a non-­sedating antihistamine 
taken regularly is particularly effective. Patients should be carefully 
instructed in how to use the nasal steroid device to achieve optimal 
drug deposition. In selected cases an α-­adrenergic agonist may 
help to decongest the nose prior to taking the topical corticoste­
roid. Patients often worry about possible side-­effects; nasal steroids 
can cause epistaxis but the amount used is insufficient to cause 
systemic effects.
If other therapy has failed, seasonal rhinitis and perennial rhinitis 
respond readily to a short course (maximum 2 weeks) of treatment 
with oral prednisolone 5-10 mg daily. Nasal polyps may respond to 
oral corticosteroids and their recurrence may be prevented by con­
tinuous use of topical corticosteroids. 
Leukotriene antagonists
If there is no response to antihistamines or topical steroids, a leuko­
triene antagonist (e.g. montelukast 10 mg daily in the evening) may 
be helpful, especially in patients with a history of NSAID sensitivity 
or concomitant asthma. 
Immunotherapy
This is used for patients with seasonal allergic rhinitis who have not 
responded to standard drugs. Both oral and injectable vaccines 
are available (see p. 63). Other forms of desensitizing vaccines are 
under development. 
Sinusitis
See page 908. 
Pharyngitis
The most common viruses causing pharyngitis are adenoviruses, 
of which there are about 32 serotypes. Endemic adenovirus infec­
tion causes the common sore throat, in which the oropharynx and 
soft palate are reddened and the tonsils are inflamed and swollen. 
Within 1-2 days the tonsillar lymph nodes enlarge. The disease 
is self-­limiting and requires only symptomatic treatment without 
antibiotics.
Over several decades the proportion of sore throats due to 
bacterial infections, such as haemolytic streptococcus, has fallen. 
Many different pathogens have been implicated in pharyngitis but 
most do not require specific treatment. Persistent and severe ton­
sillitis should be treated with phenoxymethylpenicillin 500 mg four 
times daily or cefaclor 250 mg three times daily. Amoxicillin and 
ampicillin should be avoided if there is a possibility of infectious 
mononucleosis (see p. 524), as they are likely to cause drug rashes 
in this context. 
Acute laryngotracheobronchitis
Acute laryngitis is an occasional but striking complication of upper 
respiratory tract infections, particularly those caused by parainflu­
enza viruses and measles. The condition is most severe in children 
under the age of 3 years. Inflammatory oedema extends to the vocal 
cords and the epiglottis, causing narrowing of the airway; there may 
be associated tracheitis or tracheobronchitis. The voice becomes 
hoarse, and there is a barking cough (croup) and audible stridor. 
Progressive airways obstruction may occur, with recession of the 
soft tissue of the neck and abdomen during inspiration and, in 
severe cases, central cyanosis. Steam inhalations are not helpful. 
Nebulized adrenaline (epinephrine) gives short-­term relief. Oral or 
intramuscular corticosteroids (e.g. dexamethasone) should be given 
with oxygen and adequate fluids. If steroids are used, endotra­
cheal intubation is rarely necessary. A tracheostomy is infrequently 
required. 
Acute epiglottitis
Haemophilus influenzae type b (Hib) can cause life-­threatening 
infection of the epiglottis, usually in children under 5 years of age. 
The child becomes extremely ill with a high fever, and severe air­
flow obstruction may rapidly occur. This is a life-­threatening emer­
gency and requires urgent endotracheal intubation and intravenous 
antibiotics (e.g. ceftazidime 25-150 mg/kg). Chloramphenicol (50-
100 mg/kg) is also used in some countries. The epiglottis, which is 
red and swollen, should not be inspected until facilities to maintain 
the airways are available.
Other manifestations of Hib infection are meningitis, septic 
arthritis and osteomyelitis. A highly effective vaccine is now avail­
able, which is given to infants at 2, 3 and 4 months with their primary 
immunizations against diphtheria, tetanus and pertussis (DTP). In 
many countries, this programme has reduced death rates from Hib 
infections virtually to zero. 
Influenza
The influenza virus belongs to the orthomyxovirus group and exists 
in two main forms, A and B. Influenza B is associated with localized 
outbreaks of mild disease, whereas influenza A causes worldwide 
pandemics (see p. 520). 
Clinical features
The incubation period of influenza is usually 1-3 days. The illness 
starts abruptly with a fever, shivering and generalized aching in the 
limbs. This is associated with severe headache, soreness of the 
throat and a dry cough that can persist for several weeks. Diarrhoea 
occurs in 70% of cases of H5N1 (''bird flu''). Influenza infection can 
be followed by a prolonged period of debility and depression that 
may take weeks or months to clear. 
Complications
Secondary bacterial infection is common following influenza virus 
infection, particularly with Streptococcus pneumoniae and H.', 6543),
   ('a6d58848-e2d2-5395-8daa-b1d1653ae49d', 'KUMAR_CLARK_10_2017', 'KC-C28', 948, 966, 0, '28
948  Respiratory disease 
influenzae. Secondary pneumonia caused by Staphylococcus aureus 
is rarer but more serious, and carries a mortality of up to 20%. Post-­
infectious encephalomyelitis is rare after influenza infection. 
Diagnosis and management
Laboratory diagnosis is not usually necessary in the community, 
but a definitive diagnosis can be established by demonstrating a 
four-­fold increase in complement-­fixing antibody or haemaggluti­
nin antibody measured at onset and after 1-2 weeks, or by taking 
nasopharyngeal swabs. Viral swabs should be taken for hospital 
inpatients to facilitate infection control measures.
Management is by bed rest and paracetamol, with antibiotics 
to prevent secondary infection in those with chronic bronchitis or 
cardiac or renal disease. Neuraminidase inhibitors help to shorten 
the duration of symptoms in patients with influenza, if given within 
48 hours of the first symptom. Inpatients should be cared for in 
a side room, with respiratory isolation measures in place to avoid 
cross-­infection. 
Prophylaxis
Protection by influenza vaccines is effective in only about 70% of 
people and lasts for about a year only. New vaccines have to be 
prepared to cover each change in viral antigenicity and are therefore 
in limited supply at the start of an epidemic. Nevertheless, routine 
vaccination is recommended for all individuals over 65 years of age 
and also for younger people with chronic heart disease, chronic 
lung disease (including asthma), chronic kidney disease or diabetes 
mellitus and for those who are immunosuppressed. Hospital and 
health service personnel should also be vaccinated. Influenza vac­
cine should be given to individuals who are allergic to egg protein 
with caution, as some types are manufactured in chick embryos; 
egg-­free vaccines are now available. 
Inhalation of foreign bodies
Children inhale foreign bodies, such as peanuts, more commonly 
than adults do. In adults, inhalation may occur after excess alcohol 
or under general anaesthesia (loose teeth or dentures).
When the foreign body is large, it may impact in the trachea. 
The person chokes and then becomes silent; death ensues unless 
the material is quickly removed. Guidelines for the management of 
choking should rapidly be followed (Box 28.16).
More often, impaction occurs in the right main bronchus and 
produces choking and persistent monophonic wheeze; it may lead 
to a suppurative pneumonia and/or lung abscess. 
Acute and chronic cough
Cough is one of the most common respiratory symptoms reported 
by patients. Acute cough is often defined as one that lasts less 
than 3 weeks and chronic cough one that persists more than 8 
weeks. The ''grey'' area in between is often termed subacute cough. 
Management of acute cough
Acute cough is often associated with upper respiratory tract infec­
tion, particularly in the winter months, and tends to settle after a 
few weeks (Box 28.17). However, any patient who has worrying 
symptoms or signs, such as haemoptysis, breathlessness, fever, 
weight loss, night sweats, chest pain or foreign body inhalation, 
should undergo urgent chest X-­ray to look for lung cancer, pneu­
monia or tuberculosis, in particular. However, most acute cough is 
self-­limiting and antibiotics are not indicated. 
Management of chronic cough
All patients with a chronic cough should have a chest X-­ray and 
those with X-­ray abnormalities should be investigated appropriately. 
If the chest X-­ray is normal, then the five most likely diagnoses are 
undiagnosed asthma, postnasal drip, gastro-­oesophageal reflux 
disease (see p. 1162), recent upper respiratory tract infection or 
smoking.
Spirometry should then be organized. If it reveals reversible 
airways obstruction, treatment is given as per asthma guidelines. 
Suspect choking
 • Be alert to choking, particularly if the victim is eating. 
Encourage to cough
 • Instruct the victim to cough. 
Give back blows
 • If cough becomes ineffective, give up to five back blows:
 
- Stand to the side and slightly behind the victim.
 
- Support the chest with one hand and lean the victim well forwards 
so that, when the obstructing object is dislodged, it comes out of the 
mouth rather than going further down the airway.
 
- Give five sharp blows between the shoulder blades with the heel of 
your other hand. 
Give abdominal thrusts
 • If back blows are ineffective, give up to five abdominal thrusts:
 
- Stand behind the victim and put both arms round the upper part of 
the abdomen.
 
- Lean the victim forwards.
 
- Clench your fist and place it between the umbilicus (navel) and the 
ribcage.
 
- Grasp this hand with your other hand and pull sharply inwards and 
upwards.
 
- Repeat up to five times.
 
- If the obstruction is still not relieved, continue alternating five back 
blows with five abdominal thrusts. 
Start cardiopulmonary resuscitation (CPR)
 • Start CPR if the victim becomes unresponsive:
 
- Support the victim as you lower them carefully to the ground.
 
- Immediately activate the ambulance service.
 
- Begin CPR with chest compressions.
   
(From resus.org.uk.)
Box 28.16 Sequence of steps for managing the adult victim 
who is choking
Cause
Example
Respiratory disease
Viral or bacterial infection, bronchospasm, 
chronic obstructive pulmonary disease, 
non-­asthmatic eosinophilic asthma, 
bronchiolitis, malignancy, parenchymal 
disease (e.g. interstitial lung disease, 
bronchiectasis, cystic fibrosis, sarcoido­
sis), pleural disease, aspiration
Upper airways 
disease
Postnasal drip, sinusitis, inhaled foreign 
body, tonsillar enlargement
Cardiovascular 
disease
Heart failure, mitral stenosis
Gastro-­oesophageal 
disease
Gastro-­oesophageal reflux disease, also 
associated with laryngopharyngeal 
reflux
Neurological disease
Aspiration
Drugs and irritants
Angiotensin converting enzyme (ACE) 
inhibitors, cigarette smoke
Box 28.17 Causes of cough', 5953),
   ('52fa849f-9827-569e-8b3b-826063ed62a3', 'KUMAR_CLARK_10_2017', 'KC-C28', 949, 967, 0, '28
Obstructive Respiratory Disease  949
Otherwise, based on the history, patients should have a trial of treat­
ment for the most likely cause:
 • nocturnal cough or wheeze: a 2-­week trial of oral or inhaled 
steroids
 • acid reflux: an 8-­week trial of a proton pump inhibitor
 • postnasal drip: a trial of topical steroids
 • smoking: smokers should be referred to the local smoking ces­
sation service.
Ensure that the patient is not taking an angiotensin converting 
enzyme (ACE) inhibitor.
If a chronic cough does not settle after empirical treatment and 
the aetiology remains unclear, further investigations might include 
CT chest, bronchoscopy, bronchial provocation testing, oesopha­
geal manometry and imaging of the sinuses. Referral to a specialist 
cough clinic may also be considered.
Further reading
Greiner AN, Hellings PW, Rotiroti G et al. Allergic rhinitis. Lancet 2011; 
378:2112-2122.
National Institute for Health and Care Excellence. NICE Guideline 120: Cough 
(Acute): Antimicrobial Prescribing. NICE 2019; https://www.nice.org.uk/guidance
/ng120.
Scadding GK, Kariyawasam HH, Scadding G et al. BSACI guidelines for the 
diagnosis and management of allergic and non-­allergic rhinitis. Clin Exp Allergy 
2017; 47:856-889.
https://www.worldallergy.org. World Allergy Organization: education 
programmes and allergic disease resource centre. 
OBSTRUCTIVE RESPIRATORY 
DISEASE
Asthma
Asthma is a common chronic condition whose cause is incompletely 
understood. Symptoms include wheeze, chest tightness, cough 
and shortness of breath, often worse at night. Asthma commonly 
starts in childhood between the ages of 3 and 5 years and may 
either worsen or improve during adolescence. Classically, asthma 
has three characteristics:
 • airflow limitation, which is usually reversible spontaneously or 
with treatment
 • airway hyper-­responsiveness to a wide range of stimuli (see 
later)
 • bronchial inflammation with T lymphocytes, mast cells, eosin­
ophils with associated plasma exudation, oedema, smooth muscle 
hypertrophy, matrix deposition, mucus plugging and epithelial 
damage.
In chronic asthma, inflammation may be accompanied by irre­
versible airflow limitation as a result of airway wall remodelling, 
which may involve large and small airways and mucus impaction. 
Prevalence
In many countries the prevalence of asthma has increased since 
the mid-­1980s. This increase is particularly marked in chil­
dren and young adults, with up to 15% of the population being 
affected. Asthma is more common in developed countries, with 
some of the highest rates in the UK, New Zealand and Austra­
lia, and much lower rates in East Asia, Africa and Central and 
Eastern Europe. Long-­term follow-­up in developing countries 
suggests that asthma may become more frequent as individu­
als adopt a more ''Westernized'' lifestyle but the environmental 
factors accounting for this remain unknown. Studies of occu­
pational asthma suggest that a large proportion of the work­
force (15-20%) may become asthmatic if exposed to potent 
sensitizers. Worldwide, asthma kills about 1000 people per day; 
approximately 300 million people have asthma and this figure is 
expected to rise to 400 million by 2025. 
Classification
Asthma is a complex disorder. The current thinking is that symptoms 
can be caused by several different processes. Asthma can be classi­
fied according to its trigger factors, age of onset, inflammatory sub­
types or response to therapy. There is considerable overlap between 
populations separated along these different dimensions and it is now 
increasingly common to describe clinical subtypes (or endotypes).
Many childhood-­onset asthmatics have a wheezing illness with 
inhaled allergic triggers. Some 90% of children and 70% of adults 
with persistent asthma have positive skin-­prick tests to common 
inhalant allergens such as dust mite, animal danders, pollens and 
fungi. Childhood-­onset asthma is often accompanied by eczema 
(atopic dermatitis, see p. 660).
In some people with asthma, inhaled allergens are not relevant. 
This illness often starts in middle age and attacks are triggered by 
respiratory infections. Nevertheless, many patients with adult-­onset 
asthma show positive allergen skin tests and, on close questioning, 
some of these will give a history of childhood respiratory symptoms 
suggesting that they have allergic asthma.
Non-­atopic individuals may develop asthma in middle age from 
extrinsic causes, such as sensitization to occupational agents like 
toluene diisocyanate, intolerance to NSAIDs such as aspirin, or pre­
scription of β-­adrenoceptor-­blocking agents that block the protec­
tive effect of endogenous catecholamines. Extrinsic causes must 
be considered in all cases of asthma and, where possible, avoided.
Other clinical phenotypes
Based on the clinical picture, other subtypes or endotypes of asthma 
are recognized, including ''brittle asthma'' and steroid-­resistant asthma. 
While eosinophilic airway inflammation is often present in asthma, 
there are also patients with eosinophilic bronchitis, who have sputum 
eosinophilia without wheeze. It remains unclear whether this is a pre-­
asthmatic state or whether anti-­eosinophil treatment is helpful. 
Aetiology
The major factors involved in the development of asthma and stim­
uli that can precipitate attacks are shown in Fig. 28.18.
Atopy and allergy
The term ''atopy'' was coined in the early 1900s to describe a group 
of disorders, including asthma and hayfever, that appeared to run in 
families, have positive skin-­prick tests to common inhalant allergens 
and have circulating allergen-­specific antibodies. Allergen-­specific 
IgE is present in 30-40% of the UK population, and elevated serum 
IgE levels are linked to airway hyper-­responsiveness and the prev­
alence of asthma. Serum total IgE levels are affected by several 
genetic and environmental factors.
Genetic factors
There is no single gene for asthma but several, in combination with 
environmental factors, appear to influence its development. These 
include genes that affect the production of cytokines and IgE. 
Environmental factors
Early childhood exposure to allergens and maternal smoking has 
a major influence on IgE production. Much interest focuses on the 
role of intestinal bacteria and childhood infections in shaping the 
immune system in early life. It has been suggested that growing up', 6434),
   ('b4ec9eb0-f312-5ab9-8656-a1c482b03cab', 'KUMAR_CLARK_10_2017', 'KC-C28', 950, 968, 0, '28
950  Respiratory disease 
in a relatively ''clean'' environment may predispose towards an IgE 
response to allergens (the ''hygiene hypothesis''). Conversely, growing 
up in a ''dirtier'' environment may allow the immune system to avoid 
developing allergic responses, and early-­life exposure to inhaled and 
ingested products of microorganisms, as occurs in livestock farming 
communities and developing countries, may reduce the subsequent 
risk of a child becoming allergic and/or developing asthma.
The allergens involved in allergic asthma are similar to those impli­
cated in rhinitis, although pollens are relatively less implicated in asthma. 
Most allergic asthmatics are sensitized to house-­dust mite allergens. 
Cockroach allergy has been implicated in asthma in inner-­city children 
in the USA, while allergens from furry pets (especially cats) are increas­
ingly common causes. The fungal spores from Aspergillus fumigatus 
cause a range of lung disorders, including asthma (see p. 993). 
Precipitating factors
Occupational sensitizers
Over 250 materials encountered in the workplace can cause occu­
pational asthma, which accounts for up to 15% of all asthma cases 
(Box 28.18). These are recognized occupational diseases in the UK 
and patients in insurable employment are eligible for statutory com­
pensation, provided they apply within 10 years of leaving the occu­
pation in which the asthma developed.
Asthma can be due to:
 • low-­molecular-­weight compounds, e.g. reactive chemicals such 
as isocyanates and acid anhydrides that bond chemically to epi­
thelial cells to activate them, as well as providing haptens recog­
nized by T cells
 • high-­molecular-­weight compounds, e.g. flour, organic dusts and 
other large protein molecules involving specific IgE antibodies.
Smoking increases the risk of developing some forms of occupa­
tional asthma. The proportion of employees developing occupational 
asthma depends primarily on the level of exposure. Proper enclo­
sure of industrial processes or appropriate ventilation greatly reduces 
the risk. Atopic individuals develop occupational asthma more rap­
idly when exposed to agents causing the development of specific 
IgE antibody. Non-­atopic individuals can also develop asthma when 
exposed to such agents, but after a longer period of exposure. 
Non-­specific factors
Due to their AHR, patients with asthma will respond to a wide vari­
ety of non-­specific direct and indirect stimuli, as well as reacting to 
specific allergens.
Cold air and exercise
Most asthmatics wheeze after prolonged exercise or inhalation of 
cold, dry air. Typically, the attack does not occur while exercising 
but afterwards. Exercise-­induced wheeze is driven by release of his­
tamine, prostaglandins (PGs) and leukotrienes (LTs) from mast cells, 
as well as stimulation of neural reflexes. 
Atmospheric pollution and irritant dusts, vapours and 
fumes
Many patients with asthma experience worsening of symptoms on 
exposure to tobacco smoke, car exhaust fumes, solvents, strong per­
fumes or high concentrations of airborne dust. Major epidemics have 
been recorded when large amounts of allergens are released into the 
air, and asthma exacerbations increase during summer and winter air 
pollution episodes associated with climatic temperature inversions: in 
the presence of high concentrations of ozone, particulates and NO2 in 
the summer and particulates, NO2 and SO2 in the winter. 
Diet
Increased intake of fresh fruit and vegetables has been shown to be 
protective, possibly owing to the greater consumption of antioxidants 
or other protective molecules such as flavonoids. Genetic variation in 
antioxidant enzymes is associated with more severe asthma. 
(QYLURQPHQWDOH[SRVXUHWRDOOHUJHQ
''HUPDWRSKDJRLGHVSWHURQ\VVLQXV
JUDVVSROOHQGRPHVWLFSHWV
2FFXSDWLRQDO
VHQVLWL]HUV
VHH%R[
$WPRVSKHULF
SROOXWLRQ
6XOSKXUGLR[LGH
2]RQH
3DUWLFXODWHPDWWHU
''UXJVRUDO
DQGRUWRSLFDO
16$,''V
βDGUHQRFHSWRU
EORFNLQJDJHQWV
9LUDOLQIHFWLRQV
5KLQRYLUXV
3DUDLQIOXHQ]DYLUXV
569
&ROGDLU
(PRWLRQ
*HQHWLFIDFWRUV
,UULWDQWGXVWV
YDSRXUDQG
IXPHV
3HUIXPH
&LJDUHWWHVPRNH
Fig. 28.18  Causes and triggers of asthma.  NSAIDs, non-­steroidal 
anti-­inflammatory drugs; RSV, respiratory syncytial virus.
Cause
Source/occupation
Low-­molecular-­weight (non-­IgE-­related)
Isocyanates
Polyurethane varnishes
Industrial coatings
Spray painting
Colophony fumes
Soldering/welders
Electronics industry
Wood dust
Drugs
Bleaches and dyes
Complex metal salts, e.g. 
nickel, platinum, chromium
High-­molecular-­weight (IgE-­related)
Allergens from animals and 
insects
Farmers, workers in poultry and 
seafood processing industry; 
laboratory workers
Antibiotics
Nurses, health industry
Latex
Health workers
Proteolytic enzymes
Manufacture (but not use) of ''bio­
logical'' washing powders
Complex salts of platinum
Metal refining
Acid anhydrides and polyamine 
hardening agents
Industrial coatings
Box 28.18 Occupational asthma', 4977),
   ('58ae615d-0982-54bd-9cf9-3d5825d67dd7', 'KUMAR_CLARK_10_2017', 'KC-C28', 951, 969, 0, '28
Obstructive Respiratory Disease  951
Emotion
Emotional factors influence asthma both acutely and chronically, 
but there is no evidence that patients with the disease are any 
more psychologically disturbed than their non-­asthmatic peers. 
Patients at high risk of life-­threatening attacks are understandably 
anxious. 
Drugs
NSAIDs. NSAIDs, particularly aspirin and propionic acid deriva­
tives, such as indometacin and ibuprofen, are implicated in 
triggering asthma in approximately 5% of patients. NSAID intol­
erance is especially prevalent in those with both nasal polyps 
and asthma, and is often associated with rhinitis and flushing on 
drug exposure.
Beta-­blockers. The airways have a direct parasympathetic 
innervation that tends to produce bronchoconstriction. There is 
no direct sympathetic innervation of bronchial smooth muscle, so 
antagonism of parasympathetically induced bronchoconstriction is 
critically dependent on circulating adrenaline (epinephrine) acting 
through β2-­receptors on the surface of smooth muscle cells. Inhibi­
tion of this effect by non-­selective β-­adrenoceptor-­blocking drugs, 
such as propranolol, leads to bronchoconstriction and airflow 
limitation, but only in asthmatic subjects. Selective β1-­adrenergic-­
blocking drugs, such as atenolol, may also induce attacks of 
asthma. 
Clinical features
The principal symptoms of asthma are wheezing attacks and epi­
sodic shortness of breath. Symptoms are usually worst during the 
night, especially in uncontrolled disease. Cough is a frequent symp­
tom that sometimes predominates, especially in children, in whom 
nocturnal cough can be a presenting feature. Attacks vary greatly in 
frequency and duration and may be precipitated by a wide range of 
triggers (see Fig. 28.18). Asthma is a major cause of impaired qual­
ity of life and has an impact on work and recreation, affecting both 
physical activities and emotions. 
Investigations
There is no single satisfactory diagnostic test for all patients with 
asthma.
Lung function tests
PEFR measurements on waking, prior to taking a bronchodila­
tor, before bed and after a bronchodilator are particularly useful 
in demonstrating the variable airflow limitation that characterizes 
the disease (see Figs 28.13 and 28.14). The diurnal variation in 
PEFR is a good measure of asthma activity and is of help in the 
longer-­term assessment of the patient''s disease and its response 
to treatment.
Spirometry is useful, especially in assessing reversibility. 
Asthma can be diagnosed by demonstrating a greater than 15% 
improvement in FEV1 or PEFR following inhalation of a bron­
chodilator. The carbon monoxide (CO) transfer test is normal in 
asthma. 
Histamine or methacholine bronchial provocation 
test
This was outlined on page 945. 
Trial of corticosteroids
All patients who present with severe airflow limitation should 
undergo a formal trial of corticosteroids. Prednisolone 30 mg orally 
should be given daily for 2 weeks, with lung function measured 
before and immediately after the course. A substantial improve­
ment in FEV1 (>15%) confirms the presence of a reversible element 
and indicates that the administration of inhaled steroids will prove 
beneficial to the patient. If the trial is for 2 weeks or less, the oral 
corticosteroid can be withdrawn without tailing off the dose, and 
should be replaced by inhaled corticosteroids in those who have 
responded. 
Exhaled nitric oxide
This test is a measure of airway inflammation and an index of cortico­
steroid response; it is used to assess the efficacy of corticosteroids. 
Blood and sputum tests
Patients with asthma sometimes have increased numbers of eosin­
ophils in peripheral blood (>0.4 × 109/L) but sputum eosinophilia is a 
more specific diagnostic finding. 
Chest X-­ray
There are no diagnostic features of asthma on the chest X-­ray, 
although overinflation is characteristic during an acute episode or in 
chronic severe disease. A chest X-­ray may be helpful in excluding a 
pneumothorax, which can occur as a complication, or in detecting 
the pulmonary infiltrates associated with allergic bronchopulmonary 
aspergillosis. 
Skin tests
Skin-­prick tests should be performed in all cases of asthma to 
help identify allergic trigger factors. Allergen-­specific IgE can be 
measured in serum if skin-­prick test facilities are not available, the 
patient is taking antihistamines or no suitable allergen extracts are 
available. 
Allergen provocation tests
Allergen inhalation challenge is a useful research tool; it is required 
when investigating patients with suspected occupational asthma 
but not in ordinary asthma. 
Management
The aims of treatment are to:
 • abolish symptoms
 • restore normal or best possible lung function
 • reduce the risk of severe attacks
 • enable normal growth to occur in children
 • minimize absence from school or employment.
This involves:
 • patient and family education about asthma
 • patient and family participation in treatment
 • avoidance of identified causes where possible
 • use of the lowest effective doses of convenient medications to 
minimize short-­term and long-­term side-­effects.
Many asthmatics join self-­help groups in order to improve their 
understanding of the disease and to foster self-­confidence and 
fitness.
Control of extrinsic factors
Where specific allergen triggers are identified, these should be avoided 
if possible. Sublingual allergen immunotherapy (SLIT) with house-­dust 
mites has shown a reduction in the number of asthma attacks in chil­
dren but is not recommended in adults. Active and passive smoking 
should be avoided, as should beta-­blockers in either tablet or eye-­drop 
form. Individuals intolerant to aspirin should avoid NSAIDs, although', 5783),
   ('5b23643a-c2a0-5f19-a0a6-2b0ad33e91bc', 'KUMAR_CLARK_10_2017', 'KC-C28', 952, 970, 0, '28
952  Respiratory disease 
they may tolerate cyclo-­oxygenase-­2 (COX-­2) inhibitors. About one-­
third of individuals sensitized to occupational agents may be cured if 
they are kept permanently away from exposure. 
Drug treatment
The mainstay of asthma therapy is use of inhaled therapeutic agents, 
delivered as aerosols or powders directly into the lungs (Box 28.19). 
The advantages of this method of administration are that drugs are 
delivered direct to the airways and first-­pass metabolism in the liver 
is avoided; thus lower doses are necessary and systemic unwanted 
effects are minimized. To help those who cannot coordinate activa­
tion of the aerosol and inhalation, several breath-­activated or dry 
powder devices have been developed. Patients vary in their ability 
to use such devices, and care should be taken to select an appro­
priate device and train the individual to use it properly.
Several national and international guidelines have been published 
on the treatment of asthma (Fig. 28.19), based on three principles:
 • Asthma should be self-­managed, with regular monitoring using 
a PEFR meter and an individual treatment plan that is discussed 
with each patient and written down.
Patients should be taught how to use inhalers and their technique should be 
checked regularly.
Use of a metered-­dose inhaler
 1. The canister is shaken.
 2. The patient exhales to functional residual capacity (not residual volume), 
i.e. normal expiration.
 3. The aerosol nozzle is placed to the open mouth.
 4. The patient simultaneously inhales rapidly and activates the aerosol.
 5. Inhalation is completed.
 6. The breath is held for 10 sec if possible. Even with good technique, only 
15% of the contents is inhaled and 85% is deposited on the wall of the 
pharynx and ultimately swallowed. 
Spacers
These are plastic cones or spheres inserted between the patient''s mouth 
and the inhaler. Some inhalers have a built-­in spacer extension. These are 
designed to reduce particle velocity so that less drug is deposited in the 
mouth. Spacers also diminish the need for coordination between aerosol 
activation and inhalation. They are useful in children and the elderly, and 
reduce the risk of candidiasis.
Box 28.19 Inhaled therapy for asthma
Initial add-on
therapy
Add inhaled LABA to
low-dose ICS (fixed
dose or MART)
Move up to improve control as needed
Move down to find and maintain lowest controlling therapy
Regular
preventer
Low-dose ICS
Short acting β2 agonists as requied (unless using MART) - consider moving up if using three doses a week or more
Consider
monitored
initiation of
treatment with
low-dose ICS
Diagnosis and
assessment
Evaluation: • assess symptoms, measure lung function, check inhaler technique and adherence
• adjust dose • update self-management plan • move up and down as appropriate
Asthma - suspected
Adult asthma - diagnosed
Additional
controller therapies
Consider:
Specialist
therapies
Refer patient for
specialist care
Increasing ICS to
medium dose
Adding LTRA
If no response
to LABA,
consider stopping
LABA
or
Infrequent,
short-lived
wheeze
Fig. 28.19  Summary of asthma management in adults.  ICS, inhaled corticosteroid; LABA, long-­
acting β agonist; LTRA, leukotriene receptor antagonist; MART, maintenance and reliever therapy. 
(Scottish Intercollegiate Guidelines Network/British Thoracic Society. SIGN158: British Guideline on the 
Management of Asthma: A National Clinical Guideline. SIGN/BTS 2019; Fig. 2, p. 80.)', 3492),
   ('0099e7c2-70a9-5145-af88-f119d3a09b0f', 'KUMAR_CLARK_10_2017', 'KC-C28', 953, 971, 0, '28
Obstructive Respiratory Disease  953
 • Asthma is an inflammatory disease, so anti-­inflammatory (con­
troller) therapy should be started, even in mild cases.
 • Short-­acting inhaled bronchodilators (e.g. salbutamol and terb­
utaline) should be used only to relieve breakthrough symptoms. 
Increased use of bronchodilator treatment to relieve increasing 
symptoms is an indication of deteriorating disease.
A list of drugs used in asthma is shown in Box 28.20. These are 
given in a stepwise fashion, as indicated in Fig. 28.19.
Beta2-­adrenoceptor agonists
Beta2-­adrenoceptor agonists are selective for the respiratory tract 
and do not stimulate the β1 adrenoceptors of the myocardium. 
These drugs relax the bronchial smooth muscle and are very effec­
tive in relieving symptoms, but do not affect underlying airways 
inflammation.
 • Short-­acting β agonists (SABAs), such as salbutamol 100 μg 
(called albuterol in the USA) or terbutaline 250 μg, can be taken 
as and when required, and should be prescribed as ''two puffs as 
required''.
 • Long-­acting β2-­adrenoceptor agonists (LABAs), such as sal­
meterol or formoterol, are effective by inhalation for up to 12 
hours and are given once or twice daily. They should be used in 
combination with an inhaled corticosteroid as fixed-­dose combi­
nations (e.g. salmeterol/fluticasone and formoterol/budesonide) 
in the same inhaler.
The mildest asthmatics with intermittent attacks are the only 
people who should rely on SABA treatment alone. Any patients 
using β2-­adrenoceptor agonists more than three times a week 
should be started on inhaled corticosteroids. 
Inhaled corticosteroids
All patients who have regular persistent symptoms (even mild ones) 
need regular treatment with inhaled corticosteroids. Beclometasone 
dipropionate (BDP) is the most widely used inhaled steroid and is 
available in doses of 50, 100, 200 and 250 μg per puff. Other inhaled 
steroids include budesonide, fluticasone propionate, fluticasone 
furoate, mometasone furoate and triamcinolone.
Side-­effects of inhaled steroids include oral thrush and hoarse­
ness, and patients should be instructed to rinse their mouths out 
after using the inhaler. Subcapsular cataract formation is rare but 
can occur in the elderly. Osteoporosis is less likely than with oral 
steroids but can occur with high-­dose inhaled corticosteroids 
(beclometasone or budesonide >800 μg daily). In children, inhaled 
corticosteroids at doses above 400 μg daily have been shown to 
retard short-­term growth but final heights are not affected. Inhaled 
corticosteroid use should be stepped down once asthma comes 
under control. 
Oral corticosteroids and steroid-­sparing agents
Oral corticosteroids are needed both for acute exacerbations and 
for longer-­term use when other drug regimes have not controlled 
symptoms. The dose should be kept as low as possible to minimize 
side-­effects. The effect of short-­term treatment with prednisolone 
30 mg daily is shown in Fig. 28.14. Some patients require continu­
ing treatment with oral corticosteroids. Occasionally, low doses of 
methotrexate or ciclosporin are used as steroid-­sparing agents in 
some steroid-­dependent asthmatics but biologic monoclonal anti­
bodies are now preferentially used in these patients. 
Leukotriene receptor antagonists
This class of anti-­asthma therapy targets the cysteinyl LT1 recep­
tor. Montelukast, pranlukast (only available in South-­east Asia) and 
zafirlukast are given orally and are effective in a subpopulation of 
asthma patients. However, it is not possible to predict which indi­
viduals will benefit; a 4-­week trial of leukotriene receptor antagon­
ist (LTRA) therapy is recommended before a decision is made to 
continue or stop. LTRAs should be tried in any patient who is not 
controlled on low to medium doses of inhaled steroids; their action 
is additive to that of LABAs. LTRAs are particularly useful in patients 
with aspirin-­intolerant asthma. Because these drugs are orally active 
they are helpful in patients with asthma combined with rhinitis and 
in young children with asthma and/or virus-­associated wheezing. 
Antimuscarinic bronchodilators
Muscarinic receptors are found in the respiratory tract; large airways 
contain mainly M3 receptors, whereas the peripheral lung tissue 
contains M3 and M1 receptors (see p. 931). A nebulized short-­acting 
antimuscarinic agent, ipratropium, is used in acute severe exacer­
bations of asthma (Box 28.21). Short-­acting inhaled antimuscarinic 
agents have not been shown to be of any benefit in patients who 
have asthma that is not controlled on standard therapy. Longer-­
acting antimuscarinics (tiotropium, aclidinium) can be tried in more 
severe cases. 
Anti-­inflammatory drugs
Sodium cromoglicate and nedocromil sodium prevent activation of 
many inflammatory cells, particularly mast cells, eosinophils and 
epithelial cells but not lymphocytes, by blocking a specific chlo­
ride channel, which in turn prevents calcium influx. These drugs are 
effective in patients with milder asthma but are not routinely used. 
Monoclonal antibodies
Omalizumab, a recombinant humanized monoclonal antibody 
directed against IgE, chelates free IgE and downregulates the num­
ber and activity of mast cells and basophils. It is given subcuta­
neously every 2-4 weeks, depending on total serum IgE level and 
body weight. Although expensive, it is cost-­effective in patients with 
frequent exacerbations requiring oral corticosteroids. Mepolizumab, 
reslizumab and benralizumab are newer monoclonal antibodies 
against interleukin-­5 (IL-­5) or its receptor. They have been shown to 
be effective in eosinophilic asthma and, similar to omalizumab, are 
cost-­effective in patients who have recurrent exacerbations despite 
high-­dose inhaled corticosteroids.
Short-­acting relievers
 • Inhaled β2 agonists (e.g. salbutamol (albuterol in USA), terbutaline) 
Long-­acting relievers/disease controllers
 • Inhaled long-­acting β2 agonists (e.g. salmeterol, formoterol)
 • Inhaled corticosteroids (e.g. beclometasone, budesonide, fluticasone)
 • Compound inhaled long-­acting β2 agonists and corticosteroid (e.g. 
salmeterol and fluticasone)
 • Sodium cromoglicate
 • Leukotriene modifiers (e.g. montelukast, zafirlukast, zileuton) 
Other agents with bronchodilator activity
 • Inhaled antimuscarinic agents (e.g. ipratropium, oxitropium, aclidinium)
 • Theophylline preparations
 • Oral corticosteroids (e.g. prednisolone 40 mg daily) 
Steroid-­sparing agents
 • Methotrexate
 • Ciclosporin
 • Intravenous immunoglobulin
 • Anti-­IgE monoclonal antibody - omalizumab
 • Etanercept, infliximab, lebrikizumab
Box 28.20 Drugs used in asthma', 6730),
   ('1cea32ec-52ba-57ea-9d20-996a772593f4', 'KUMAR_CLARK_10_2017', 'KC-C28', 954, 972, 0, '28
954  Respiratory disease 
Currently in development is a wide range of other monoclonal 
antibody therapies against Th2 cytokine targets such as thymic 
stromal lymphopoietin (TSLP), thought to be important in asthma 
pathology. 
Antibiotics
There is little evidence that antibiotics are helpful in managing 
patients with acute asthma. During acute exacerbations, yellow or 
green sputum containing eosinophils and bronchial epithelial cells 
may be coughed up. This is usually due to viral rather than bacterial 
infection and antibiotics are not required.
There is mixed evidence in severe asthma for long-­term treat­
ment with the macrolide antibiotic azithromycin, which has both 
anti-­inflammatory and antibacterial actions. 
Bronchial thermoplasty
Bronchial thermoplasty is a novel approach for moderate to severe 
persistent asthma. This bronchoscopic procedure uses radiofre­
quency radiation to heat the bronchial wall and reduce the mass of 
airway smooth muscle, decreasing bronchoconstriction. It is cur­
rently being evaluated. 
Asthma attacks
Although these may occur spontaneously, asthma exacerba­
tions are most commonly caused by lack of treatment adherence, 
respiratory virus infections associated with the common cold, 
and exposure to an allergen or triggering drug, e.g. an NSAID. 
Whenever possible, patients should have a written personalized 
plan that they can implement in anticipation or at the start of an 
exacerbation that includes the early use of a short course of oral 
corticosteroids. If the PEFR is >150 L/min, patients may improve 
dramatically on nebulized therapy and may not require hospital 
admission. Their regular treatment should be increased, to include 
treatment for 2 weeks with 30-60 mg of prednisolone, followed 
by substitution with an inhaled corticosteroid preparation. Short 
courses of oral prednisolone can be stopped abruptly without tail­
ing down the dose. 
Acute severe asthma
The term acute severe asthma is used to mean an exacerbation of 
asthma that has not been controlled by the use of standard medication.
Patients with acute severe asthma typically have:
 • an inability to complete a sentence in one breath
 • a respiratory rate of ≥25 breaths/min
 • a tachycardia of ≥110 b.p.m. (pulsus paradoxus is not useful, as 
it is present in only 45% of cases)
 • a PEFR of 33-50% of predicted normal or best.
Features of life-­threatening attacks are:
 • a silent chest, cyanosis or feeble respiratory effort
 • exhaustion or altered level of consciousness
 • bradycardia, hypotension or arrhythmia
 • a PEFR of <33% of predicted normal or best (approximately 
150 L/min in adults) or SpO2 of <92%.
Arterial blood gases should always be measured in asthmatic 
patients requiring admission to hospital, with particular attention 
paid to the PaCO2. Pulse oximetry is useful in monitoring oxy­
gen saturation during the admission and can reduce the need for 
repeated arterial puncture.
Features suggesting very severe life-­threatening attacks are:
 • a high PaCO2 of >6 kPa
 • severe hypoxaemia: PaO2 <8 kPa despite treatment with oxygen
 • a low and/or falling arterial pH.
Management (see Box 28.21) consists of nebulized short-­
acting bronchodilators; nebulized antimuscarinics (e.g. ipratropium 
bromide) are also helpful. Intravenous hydrocortisone should be 
given together with prednisolone (40-60 mg daily) orally. If symp­
toms are not controlled, consider a single dose of intravenous mag­
nesium sulphate (1.2 g-2 g infusion over 20 min).
Intravenous β2-­adrenoceptor agonists or aminophylline may 
be considered. Ventilation is required for patients who deteriorate 
despite this initial regimen. A chest X-­ray is helpful to exclude pneu­
mothorax and other causes of dyspnoea.
Further reading
Chung KF, Wenzel SE, Brozek JL et al. International ERS/ATS guidelines 
on definition, evaluation and treatment of severe asthma. Eur Respir J 2014; 
43:343-373.
Scottish Intercollegiate Guidelines Network/British Thoracic Society. 
SIGN 153: British Guideline on the Management of Asthma. SIGN/BTS 2016; 
https://www.brit-­thoracic.org.uk/.
Wong GWK. How should we treat patients with mild asthma? N Engl J Med 
2019; 380:2064-2066. 
Acute bronchitis
Acute bronchitis in previously healthy subjects is often viral. Bact­
erial infection with Strep. pneumoniae or H. influenzae is a common 
sequel to viral infections, and is more likely to occur in cigarette 
smokers or people with COPD.
The illness begins with an irritating, non-­productive cough, 
together with discomfort behind the sternum. There may be associ­
ated chest tightness, wheezing and shortness of breath. Later the 
cough becomes productive, with yellow or green sputum. There is 
a mild fever and a neutrophil leucocytosis; wheeze with occasional 
crackles can be heard on auscultation. In otherwise healthy adults the 
disease improves spontaneously in 4-8 days without serious illness.
Antibiotics are often given (e.g. amoxicillin 250 mg three times 
daily), but it is not known whether they hasten recovery in otherwise 
healthy individuals and in most cases they should not be given. 
At home
 1. The patient is assessed. Tachycardia, a high respiratory rate and inability 
to speak in sentences indicate a severe attack.
 2. If the peak expiratory flow rate (PEFR) is <150 L/min (in adults), an 
ambulance should be called.
 3. Nebulized salbutamol 5 mg or terbutaline 10 mg is administered.
 4. Hydrocortisone 200 mg i.v. is given.
 5. Oxygen 40-60% is given if available.
 6. Prednisolone 60 mg is given orally. 
In hospital
 1. The patient is reassessed.
 2. Oxygen 40-60% is given.
 3. The PEFR and O2 saturation are measured.
 4. Nebulized salbutamol 5 mg or terbutaline 10 mg is repeated and 
administered 4-­hourly.
 5. Nebulized ipratropium bromide 0.5 mg is added to nebulized 
salbutamol/terbutaline.
 6. Hydrocortisone 200 mg i.v. is given.
 7. Prednisolone is continued at 40-60 mg orally daily for at least 5 days.
 8. Arterial blood gases are measured; if the PaCO2 is >8, ventilation may 
be required.
 9. A chest X-­ray is performed to exclude pneumothorax.
 10. If there is no improvement, i.v. magnesium sulphate is given at 1.2-2 g 
over 20 min.
 11. If there is still no improvement, urgent transfer to the intensive 
treatment unit is arranged.
Box 28.21 Treatment of acute severe asthma', 6392),
   ('5b547c1d-7680-5ce2-a5fb-c56e515a10dd', 'KUMAR_CLARK_10_2017', 'KC-C28', 955, 973, 0, '28
Obstructive Respiratory Disease  955
Chronic bronchitis
Chronic bronchitis, one of the clinical syndromes of COPD (see 
next section), is classically defined as a daily productive cough for 3 
months per year for 2 consecutive years. 
Chronic obstructive pulmonary disease
Definition
Chronic obstructive pulmonary disease (COPD) has been described 
as ''a disease state characterized by airflow limitation that is not 
fully reversible. The airflow limitation is usually both progressive 
and associated with an abnormal inflammatory response of the 
lungs to noxious particles or gases.'' COPD is an overarching diag­
nosis that brings together a variety of clinical syndromes (emphy­
sema, small airways disease and chronic bronchitis) associated 
with airflow limitation and destruction of the lung parenchyma. 
There is resultant hyperinflation of the lungs, ventilation/perfusion 
mismatch, increased work of breathing and breathlessness.
The condition is associated with a number of co-­morbidities, 
such as ischaemic heart disease, hypertension, diabetes, heart 
failure and cancer, suggesting that it may be part of a generalized 
systemic inflammatory process. 
Epidemiology and aetiology
COPD is caused by long-­term exposure to toxic particles and gases. 
In developed countries, cigarette smoking accounts for over 90% 
of cases. In developing countries, other factors are also implicated, 
such as inhalation of smoke from biomass heating fuels and cooking 
in poorly ventilated areas. Only 10-20% of smokers develop COPD, 
which suggests that there is an underlying individual susceptibility.
Urbanization, air pollution, socioeconomic class and occupation 
may also play a part in the aetiology but these effects are difficult to 
separate from that of smoking. Some animal studies suggest that 
diet could be a risk factor for COPD but this has not been proven 
in humans.
The economic burden of COPD is considerable. In the UK COPD 
causes approximately 18 million lost working days annually for men 
and 2.1 million lost working days for women, accounting for about 
7% of all days of absence from work due to sickness. Nevertheless, 
the number of COPD admissions to UK hospitals has been falling 
steadily since the mid-­1980s. 
Pathophysiology
Pathologically, there is evidence of airways inflammation and struc­
tural changes within the airways and the lung parenchyma.
Structural changes
Structurally, there may be evidence of emphysema and small air­
ways disease, with increased mucus-­producing goblet cells in the 
bronchial mucosa, which may lead to chronic bronchitis (Figs 28.20 
and 28.21). The physiological consequence of these changes is the 
development of airflow limitation.
Pathologically, there is evidence of both acute and chronic 
inflammation; endobronchial biopsies demonstrate a predominance 
of neutrophils, CD8-­predominant lymphocytes and macrophages. 
This chronic inflammation results in scarring and fibrosis of the 
small airways. In addition, there is destruction of the alveolar walls, 
which results in emphysema. The phenotype of COPD will differ, 
depending on the predominance of small airways disease, emphy­
sema or chronic bronchitis. 
Emphysema
Emphysema is defined as abnormal and permanent enlargement 
of air spaces distal to the terminal bronchiole, accompanied by 
destruction of their walls. It is classified according to the distribution:
 • Centri-­acinar emphysema. Distension and damage of lung tis­
sue are concentrated around the respiratory bronchioles, while 
the more distal alveolar ducts and alveoli tend to be well pre­
served. This form of emphysema is extremely common.
 • Pan-­acinar emphysema. This is less common but is the type 
associated with α1-­antitrypsin deficiency (see later). Distension 
and destruction affect the whole acinus, and in severe cases the 
lung is just a collection of bullae. Severe airflow limitation and 
mismatch occur.
Fig. 28.20  Chronic obstructive pulmonary disease (COPD).  Sec­
tion of bronchial mucosa stained for mucus glands by periodic 
acid-Schiff (PAS) showing an increase in mucus-­secreting goblet cells 
(arrowed). (Courtesy of Dr J Wilson and Dr S Wilson, University of 
Southampton.)
/RVVRILQWHUVWLWLDO
VXSSRUW
,QILOWUDWLRQZLWK
QHXWURSKLOVDQG
&''O\PSKRF\WHV
0XFXVJODQG
K\SHUSODVLD
6TXDPRXV
PHWDSODVLD
,QFUHDVHG
HSLWKHOLDO
PXFRXV
FHOOV
Fig. 28.21  Pathological changes in the airways in chronic ob­
structive pulmonary disease.', 4467),
   ('f07db1f7-6681-5257-940b-bb4e2d856001', 'KUMAR_CLARK_10_2017', 'KC-C28', 956, 974, 0, '28
956  Respiratory disease 
 • Irregular emphysema. There is scarring and damage that affect 
the lung parenchyma patchily, independent of acinar structure.
Emphysema leads to expiratory airflow limitation and air trap­
ping. The loss of lung elastic recoil results in an increase in TLC. 
Premature closure of airways limits expiratory flow while the loss of 
alveoli decreases capacity for gas transfer.
The classic Fletcher and Peto studies (Fig. 28.22) showed a 
loss of 50 mL per year in FEV1 in patients with COPD compared 
with 20 mL per year in healthy people. A more recent study has 
shown a 40 mL loss per year but in only 38% of the patients stud­
ied. Reliable biomarkers to predict the rate of decline have not 
been identified. 
Pathogenesis
Cigarette smoking
Bronchoalveolar lavage and biopsies of the airways of smokers 
show increased numbers of neutrophil granulocytes. These granu­
locytes can release elastases and proteases; an imbalance between 
protease and antiprotease activity is a causative factor in the devel­
opment of emphysema.
Mucous gland hypertrophy in the larger airways is thought to be 
a direct response to persistent irritation resulting from the inhalation 
of cigarette smoke. The smoke has an adverse effect on surfactant, 
favouring over-­distension of the lungs. 
Infections
Respiratory infections are often the precipitating cause of acute 
exacerbations of the disease. It is less clear whether infection is 
responsible for the progressive airflow limitation that characterizes 
disabling COPD. Prompt use of antibiotics and routine vaccinations 
against influenza and pneumococci are appropriate. 
Alpha1-­antitrypsin deficiency
Alpha1-­antitrypsin is a proteinase inhibitor produced in the liver; it 
is secreted into the blood and diffuses into the lung. Here it inhibits 
proteolytic enzymes such as neutrophil elastase, which are capable 
of destroying alveolar wall connective tissue. In α1-­antitrypsin defi­
ciency, the protein accumulates in the liver, leading to low levels in 
the lung.
More than 75 alleles of the α1-­antitrypsin gene have been 
described. The three main phenotypes are MM (normal), MZ (het­
erozygous deficiency) and ZZ (homozygous deficiency). Hereditary 
deficiency of α1-­antitrypsin accounts for about 2% of UK emphy­
sema cases. Deficiency can also cause liver disease (see p. 1302). 
Clinical features
Symptoms
The characteristic symptoms of COPD are productive cough with 
white or clear sputum, wheeze and breathlessness. Individuals 
will be more prone to lower respiratory tract infections. Systemic 
effects include hypertension, osteoporosis, depression, weight 
loss and reduced muscle mass with general weakness and right 
heart failure. 
Signs
In mild COPD there may be no signs or just quiet wheeze 
throughout the chest. In severe disease the patient is tachy­
pnoeic, with prolonged expiration. The accessory muscles of 
respiration are used and there may be intercostal indrawing on 
inspiration and pursing of the lips on expiration (see p. 932). The 
cricosternal distance is reduced. Chest expansion is poor, the 
lungs are hyperinflated and there is loss of the normal cardiac 
and liver dullness.
Patients who remain responsive to CO2 are usually breathless 
and rarely cyanosed. Heart failure and oedema are rare features, 
except as terminal events. In contrast, patients who become insen­
sitive to CO2 are often oedematous and cyanosed but not par­
ticularly breathless. Those with hypercapnia may have peripheral 
vasodilation, a bounding pulse, and a coarse flapping tremor of 
the outstretched hands. Severe hypercapnia causes confusion and 
progressive drowsiness. Papilloedema may be present but this is 
neither specific nor sensitive as a diagnostic feature.
Patients in the later stages may develop respiratory failure, pul­
monary hypertension and cor pulmonale. 




6WRSSHGDW
6WRSSHGDW
''LVDELOLW\
''HDWK
1HYHUVPRNHGRUQRW
VXVFHSWLEOHWRLWVHIIHFWV
6PRNHGUHJXODUO\DQG
VXVFHSWLEOHWRLWVHIIHFWV

$JH\HDUV
RI)(9YDOXHDWDJH\HDUV



Fig. 28.22  Influence of smoking on airflow limitation.  FEV1, 
forced expiratory volume in 1 sec. (From Fletcher CM, Peto R. 
The natural history of chronic airflow obstruction. Bri Med J 1977; 
1:1645.)
Minimal symptom 
statement
Score
Maximal symptoms
Score
I never cough
0 1 2 3 4 5 6
I cough all the time
I have no phlegm 
at all
0 1 2 3 4 5 6
My chest is full of 
phlegm
My chest doesn''t 
feel tight at all
0 1 2 3 4 5 6
My chest feels very 
tight
When I walk up a 
hill or one flight 
of stairs, I do 
not feel breath­
less at all
0 1 2 3 4 5 6
When I walk up a hill 
or one flight of 
stairs I am very 
breathless
I am not limited 
doing any ac­
tivities at home
0 1 2 3 4 5 6
I am very limited 
during activities at 
home
I am confident 
leaving home 
despite my lung 
condition
0 1 2 3 4 5 6
I am not at all 
confident leaving 
home because of 
my lung condition
I sleep soundly
0 1 2 3 4 5 6
I don''t sleep soundly 
because of my 
lung condition
I have lots of 
energy
0 1 2 3 4 5 6
I have no energy
Total score
Box 28.22 COPD Assessment Test (CAT)
(From Jones PW, Harding G, Berry P et al. Development and first validation of the COPD 
Assessment Test. Eur Respir J 2009; 34:648-654.)', 5286),
   ('fdf891bc-37be-50d4-87e1-139d06b27d96', 'KUMAR_CLARK_10_2017', 'KC-C28', 957, 975, 0, '28
Obstructive Respiratory Disease  957
Diagnosis
This is usually clinical and based on a history of breathlessness and 
sputum production in a chronic smoker. In the absence of a history 
of cigarette smoking, asthma is a more likely explanation, unless 
there is a family history suggesting α1-­antitrypsin deficiency.
No individual clinical feature is diagnostic. The patient may have 
signs of hyperinflation and typical pursed lip respiration. There may 
be signs of over-­inflation of the lungs (e.g. loss of liver dullness on 
percussion) but this also occurs in other diseases such as asthma. 
Conversely, centri-­acinar emphysema may be present without signs of 
over-­inflation. The chest may become ''barrel-­shaped'' but this can also 
result from osteoporosis of the spine in older men without emphysema.
The degree of breathlessness may be recorded using the Medical 
Research Council (MRC) dyspnoea score, while the COPD Assessment 
Test (CAT) is a patient scored symptom tool that measures the impact 
of the disease on the individual''s health and wellbeing (Box 28.22). 
Investigations
 • Lung function tests show evidence of airflow limitation (see 
Fig. 28.23). The FEV1:FVC ratio is reduced and the PEFR is low. 
In many patients the airflow limitation is partly reversible (usu­
ally a change in FEV1 of <15%). Lung volumes may be normal 
or increased; carbon monoxide gas transfer factor is low when 
significant emphysema is present.
 • Chest X-­ray is often normal, even when disease is advanced. 
The classic features are over-­inflation of the lungs with low, flat­
tened diaphragms, and sometimes the presence of large bullae. 
Blood vessels may be ''pruned'', with large proximal vessels and 
relatively little blood visible in the peripheral lung fields.
 • HRCT scans are useful, particularly when the plain chest X-­ray 
is normal.
 • Haemoglobin level and packed cell volume can be elevated 
as a result of persistent hypoxaemia (secondary polycythaemia; 
see p. 356).
 • Blood gases may be helpful to determine if there is any evi­
dence of respiratory failure.
 • Sputum examination may reveal Strep. pneumoniae, H. influ­
enzae and Moraxella catarrhalis, which can cause infective exac­
erbations. Many acute episodes are viral in origin.
 • ECG is often normal. If a patient has pulmonary hypertension 
secondary to COPD, the P wave is tall (P pulmonale), and there 
may be a right bundle branch block and evidence of right ven­
tricular hypertrophy (see p. 1055).
 • Echocardiography is useful to assess cardiac function where 
there is disproportionate dyspnoea.
 • α1-­Antitrypsin levels and genotype are worth measuring in pre­
mature disease or life-­long non-­smokers. 
Management
See Fig. 28.23 for management strategies.
Smoking cessation
The single most useful measure is to persuade the patient to stop 
smoking. Even in advanced disease, this may slow down the rate 
of deterioration and prolong the time before disability and death 
occur (see Fig. 28.22). Smoke from burning biomass fuels in poorly 
ventilated homes should also be reduced. 
Drug therapy
This is used both for the short-­term management of exacerbations 
and for the long-­term relief of symptoms. Many of the drugs used 
are similar to those employed in asthma (see p. 952).
Bronchodilators
 • β-­Adrenoceptor agonists. Many patients with mild COPD feel 
less breathless after inhaling a β-­adrenergic agonist such as sal­
butamol (200 μg every 4-6 h). In more severe airway limitation 
(moderate and severe COPD) a long-­acting β2 agonist should be 
used.
 • Antimuscarinic drugs. Regular use of a LAMA (such as inhaled 
tiotropium) improves lung function, symptoms of dyspnoea and 
quality of life. Use of a LAMA does not prevent the decline in FEV1.
 • Theophyllines. Long-­acting preparations of theophylline are of 
little benefit in COPD. 
Phosphodiesterase type 4 inhibitors
Roflumilast is a phosphodiesterase inhibitor with anti-­inflammatory 
properties. It is used as an adjunct to bronchodilators for maintenance treatment in those patients with an FEV1 of less than 50% and 
chronic bronchitis. 
Corticosteroids
Inhaled corticosteroids are recommended in patients with frequent 
exacerbations or a FEV1 of less than 50% predicted. Demonstration 
of a blood eosinophilia may identify patients who are more likely 
to have a beneficial response to inhaled corticosteroid therapy. 
High-­dose inhaled steroids are not advised, as their use is linked to 
increased rates of pneumonia.
Oral corticosteroids are prescribed in the context of an acute 
exacerbation. 
Antibiotics
Prompt antibiotic treatment shortens exacerbations and should 
always be given in acute episodes, as it may prevent hospital 
admission and further lung damage. Patients can be given antibiot­
ics to keep at home, starting them as soon as their sputum turns 
yellow or green.
In patients who experience frequent exacerbations, long-­term 
treatment with macrolide antibiotics such as azithromycin has been 
shown to reduce exacerbations and improve quality of life. 
Mucolytic agents
These reduce sputum viscosity and can reduce the number of 
acute exacerbations. A meta-­analysis showed that mucolytics such 
as carbocysteine are useful in preventing COPD exacerbations in 
those who experience them frequently. 
Oxygen therapy
Two controlled trials (chiefly in males) have shown improved survival 
with continuous administration of oxygen at 2 L/min via nasal prongs 
to achieve an oxygen saturation of more than 90% for large propor­
tions of the day and night. Survival curves from these two studies 
are shown in Fig. 28.24. Only 30% of those not receiving long-­term 
In patients with FEV1/FVC < 0.70:
GOLD 1:
Mild
FEV1 ≥ 80% predicted
GOLD 2:
Moderate
50% ≤ FEV1 < 80% predicted
GOLD 3:
Severe
30% ≤ FEV1 < 50% predicted
GOLD 4:
Very severe
FEV1 < 30% predicted
Box 28.23 Classification of airflow limitation severity in 
COPD (based on post-bronchodilator FEV1)
(From Global Initiative for Chronic Obstructive Lung Disease (GOLD), 2016; 
www.goldcopd.com.)', 6075),
   ('76152a51-ebd8-560a-a2f1-dc23f0e36c1f', 'KUMAR_CLARK_10_2017', 'KC-C28', 958, 976, 0, '28
958  Respiratory disease 
oxygen therapy survived for more than 5 years. A fall in pulmonary 
artery pressure was achieved if oxygen was given for 15 hours daily, 
but substantial improvement in mortality was achieved only by the 
administration of oxygen for 19 hours daily. These results suggest 
that long-­term continuous domiciliary oxygen therapy will benefit 
patients who have a:
 • PaO2 of <7.3 kPa (55 mmHg) when breathing air; measurements 
should be taken on two occasions at least 3 weeks apart after 
appropriate bronchodilator therapy (Box 28.24)
 • PaO2 of <8 kPa with secondary polycythaemia, nocturnal hypox­
aemia, peripheral oedema or evidence of pulmonary hyperten­
sion
 • carboxyhaemoglobin of <3% (i.e. patients who have stopped 
smoking).
Domiciliary oxygen is best provided via an oxygen concentrator. 
Pulmonary rehabilitation
Pulmonary rehabilitation courses are an essential part of manage­
ment in COPD, and randomized control trials have shown them to 
improve symptoms of fatigue and dyspnoea, as well as exercise 
tolerance. 
Additional measures
 • Vaccines. Patients with COPD should receive a single dose of 
the polyvalent pneumococcal polysaccharide vaccine and yearly 
influenza vaccinations.
 • α1-­Antitrypsin replacement. Weekly or monthly infusions of 
­α1-­antitrypsin have been recommended for patients with ­serum 
levels <310 mg/L and abnormal lung function. Whether this 
modifies long-­term progression remains to be determined.
 • Heart failure. This should be treated (see p. 1073).
6XSSOHPHQWDOWKHUDS\
)(9 
6WHSZLVH
GUXJWKHUDS\
+HDOWKFDUH
6\PSWRPV
(YDOXDWLRQDQGWUHDWPHQWRIK\SR[DHPLD
HJKRPHR[\JHQ
3XOPRQDU\UHKDELOLWDWLRQ
&RPELQDWLRQRILQKDOHGFRUWLFRVWHURLG
DQGORQJDFWLQJβDJRQLVW
&RQVLGHUWKHRSK\OOLQH
&RPELQDWLRQRIPXVFDULQLFDQGβDJRQLVWEURQFKRGLODWRU
/RQJDFWLQJLQKDOHGβDJRQLVWEURQFKRGLODWRU
6KRUWDFWLQJLQKDOHGβDJRQLVWEURQFKRGLODWRU
IRUDFXWHUHOLHIRIV\PSWRPV
6LQJOHVKRUWDFWLQJ
LQKDOHGβDJRQLVWEURQFKRGLODWRU
3QHXPRFRFFDODQGDQQXDOLQIOXHQ]DYDFFLQDWLRQ
6PRNLQJFHVVDWLRQ
5HJXODUDVVHVVPHQWRIOXQJIXQFWLRQ
/XQJUHGXFWLRQVXUJHU\
6LQJOHOXQJWUDQVSODQWDWLRQ
Fig. 28.23  Algorithm for the treatment of chronic obstructive pulmonary disease.  The various 
components of management are shown as the forced expiratory volume in 1 sec (FEV1) decreases and 
the symptoms become more severe. ( After Sutherland ER, Cherniack RM. Management of chronic 
obstructive pulmonary disease. N Engl J Med 2004; 350:2689-2697. © 2004 Massachusetts Medical 
Society. All rights reserved.)











2KRXUV
2KRXUV
2KRXUV
1R2
7LPHPRQWKV
&XPXODWLYHVXUYLYDO








Fig. 28.24  Cumulative survival curves for patients receiving 
oxygen.  Oxygen doses are in hours per day.', 2828),
   ('bc4bf643-a2fa-5111-8f2b-6f74b99d4f0a', 'KUMAR_CLARK_10_2017', 'KC-C28', 959, 977, 0, '28
Obstructive Respiratory Disease  959
 • Secondary polycythaemia. This requires venesection if the 
packed cell volume is >55%.
 • Sensation of breathlessness. Short-­acting sedation such 
as sublingual lorazepam or opiates may be a helpful palliative 
measure for intractable dyspnoea. Other useful adjuncts include 
breathing techniques and fan therapy.
 • Air travel. Commercial aircraft are pressurized to the equivalent of 
2000-2400 m altitude. In healthy people, this causes PaO2 to fall 
from 13.5 to 10 kPa, leading to a trivial 3% drop in oxygen satu­
ration, but patients with moderate COPD may desaturate signifi­
cantly. The desaturation associated with air travel can be simulated 
by breathing 15% oxygen at sea level. Patients whose saturation 
drops below 85% within 15 minutes should be advised to contact 
their airline to request supplemental oxygen during their flight.
 • Surgery. Some patients have large emphysematous bullae that 
reduce lung capacity. Surgical bullectomy can enable adjacent 
areas of collapsed lung to re-­expand, thereby restoring func­
tion. In addition, carefully selected patients with severe COPD 
(FEV1 <1 L) have been treated with lung volume reduction sur­
gery. Initial studies suggested that ventilation was improved and 
patients felt less breathless, although mortality was unchanged. 
However, a controlled trial in severe emphysema found in­
creased mortality and no improvement in the patient''s condition. 
Single lung transplantation (see p. 994) is used for end-­stage 
emphysema.
 • Endobronchial valves. These occlude airways of hyperinflated 
emphysematous lungs and effectively achieve lung volume re­
duction. In selected patients, studies have shown an improve­
ment in quality of life and exercise tolerance. 
COPD exacerbation
Acute exacerbations may be precipitated by a viral or bacterial 
infection. Patients may have symptoms of cough, acute broncho­
spasm and dyspnoea. Type I and type II respiratory failure may 
occur as a consequence of a COPD exacerbation.
Management consists of the following measures:
 • Airway, breathing and circulation. These should be assessed 
(see Ch. 10).
 • Oxygen therapy. COPD is by far the most common cause of 
respiratory failure. In managing respiratory failure, the main 
goal is to improve the PaO2 by continuous oxygen therapy. 
A fixed-­percentage mask (Venturi mask, Fig. 28.25) is used 
to deliver controlled concentrations of oxygen. Initially, 24% 
oxygen is given, and the concentration of inspired oxygen can 
be gradually increased, provided the PaCO2 does not rise un­
acceptably. In type II respiratory failure, the PaCO2 is elevated 
and the patient is dependent on hypoxic drive. In this setting, 
giving additional oxygen will nearly always cause a further rise 
in PaCO2. Patients at risk of hypercapnia should be managed 
with oxygen therapy to maintain the saturations within a tar­
get range of 88-92%. It is important to monitor arterial blood 
gases closely if there is any risk of decompensated type II res­
piratory failure. If there is evidence of respiratory acidosis (pH 
<7.35 with an elevated PaCO2), despite medical management, 
the patient should be considered for non-­invasive ventilation 
unless there are any contraindications (Fig. 28.26).
 • Corticosteroids, antibiotics and bronchodilators. These 
should be administered in the acute phase of an exacerbation 
but decisions on long-­term use should wait until the patient has 
recovered (see earlier).
 • Removal of retained secretions. Patients should be encour­
aged to cough up secretions. Physiotherapy is helpful in achiev­
ing adequate chest clearance. 
Type II respiratory failure in COPD
 • Respiratory support (see p. 227). Non-­invasive ventilation 
should be offered if a patient has a persistent respiratory aci­
dosis with a pH of <7.35. Randomized controlled trials have 
demonstrated that non-­invasive ventilation (NIV) reduces the 
need for intubation and lowers mortality. Indications and con­
traindications are shown in Boxes 28.25 and 28.26. Assisted 
ventilation with an endotracheal tube is occasionally neces­
sary for patients with COPD who have severe respiratory fail­
ure but only when there is a clear precipitating factor and the 
overall prognosis is reasonable. Assessing the likelihood of 
reversibility in an acute setting can present a difficult ethical 
problem. 
Prognosis of COPD
Predictors of a poor prognosis are increasing age and worsen­
ing airflow limitation: that is, decreasing FEV1. A predictive index 
 • Chronic obstructive pulmonary disease with a PaO2 <7.3 kPa when 
breathing air during a period of clinical stability
 • Chronic obstructive pulmonary disease with a PaO2 7.3-8 kPa in the 
presence of secondary polycythaemia, nocturnal hypoxaemia, peripheral 
oedema or evidence of pulmonary hypertension
 • Severe chronic asthma with a PaCO2 <7.3 kPa or persistent disabling 
breathlessness
 • Diffuse lung disease with a PaO2 <8 kPa and patients with PaO2 >8 kPa 
with disabling dyspnoea
 • Cystic fibrosis when a PaO2 <7.3 kPa or if PaO2 7.3-8 kPa in the pres­
ence of secondary polycythaemia, nocturnal hypoxaemia, pulmonary 
hypertension or peripheral oedema
 • Pulmonary hypertension without parenchymal lung involvement when 
PaO2 <8 kPa
 • Obstructive sleep apnoea despite continuous positive airways pressure 
therapy, after specialist assessment
 • Pulmonary malignancy or other terminal disease with disabling dyspnoea
 • Heart failure with a daytime PaO2 <7.3 kPa (on air) or with nocturnal 
hypoxaemia
Box 28.24 Guidelines for home oxygen use in adults (British 
Thoracic Society guidelines, June 2015)
([SLUHGDLU
2
$LU
$LU
Fig. 28.25  ''Fixed-­performance'' device for administration of 
oxygen to spontaneously breathing patients (Venturi mask).  
Oxygen is delivered through the injector of the Venturi mask at a given 
flow rate. A proportionate amount of air is entrained and the inspired 
oxygen can be predicted accurately. Masks are available that deliver 
24%, 28% and 35% oxygen.', 6074),
   ('7512b952-e19c-55be-a252-0a31c54016cd', 'KUMAR_CLARK_10_2017', 'KC-C28', 960, 978, 0, '28
960  Respiratory disease 
Sit up
Measure saturations - if
necessary targeted oxygen
therapy to maintain saturations
at preferred target range
For those at risk of
hypercapnic respiratory failure -
target range 88-92%
Oral or intravenous
corticosteroids
Nebulized bronchodilators -
salbutamol and ipratropium
Chest physiotherapy if
difficulty clearing secretions
Acute exacerbation of COPD
Assess airway, breathing and
circulation
Cardiopulmonary arrest -
follow resuscitation
guidelines
CXR
Pneumothorax
Chest drain
 (may require CT
guidance if complex
bullous disease)
Pneumonia
Antibiotics
ABG
pH <7.35
PaO2 <8 kPa
PaCO2 >6.5 kPa
pH >7.35
PaO2 <8 kPa
PaCO2 <6.5 kPa
Controlled oxygen therapy with a
Venturi mask to maintain target
saturations according to prescribed
target range
88-92% if risk of hypercapnia
Continue management with
nebulizers and steroids
Repeat ABG if increasing oxygen
requirements, increasing breathlessness
Controlled oxygen therapy with a
Venturi mask to maintain target
saturations - 88-92%
Continue management with
nebulizers and steroids
Repeat ABG in 30-60 min
Repeat ABG- If pH <7.35 with PaCO2 >6.5 kPa - NIV
should be considered if clinically appropriate (see acute
NIV section) - refer to senior
Review and discuss ceiling of care
If deterioration despite NIV and clinically
appropriate, consider invasive ventilation
Fig. 28.26  Algorithm for the treatment of respiratory failure in COPD.  BiPAP, bilevel positive airway 
pressure; CPAP, continuous positive airway pressure; CXR, chest X-­ray. NIV, non-invasive ventilation.
(BODE, body mass index, degree of airflow obstruction, dyspnoea 
and exercise capacity) is shown in Box 28.27. A patient with a 
BODE index of 0-2 has a 4-­year mortality rate of 10%, compared 
with 80% in someone with a BODE index of 7-10. This scoring 
tool may be useful in determining timing of referral for transplant 
consideration. 
Obstructive sleep apnoea
Obstructive sleep apnoea (OSA) is a form of sleep-­disordered breath­
ing that is characterized by upper airway collapse resulting in obstruc­
tive apnoeas and hypopnoeas with desaturation. The prevalence of 
this condition is 3-5% of the population and it occurs most often in 
overweight, middle-­aged men. The prevalence of OSA increases with', 2274),
   ('380bebd2-08c9-5109-948d-f5139fa7cd7e', 'KUMAR_CLARK_10_2017', 'KC-C28', 961, 979, 0, '28
Obstructive Respiratory Disease  961
age, menopause, obesity and endocrine conditions such as acromeg­
aly and hypothyroidism. Obesity is increasing in developed countries 
and so the incidence of OSA is also predicted to rise. OSA can occur 
in children, particularly those with enlarged tonsils or trisomy 21. The 
major symptoms and their frequency are listed in Box 28.28. 
Pathophysiology
During sleep, activity of the respiratory muscles is reduced, espe­
cially during rapid eye movement (REM) sleep when the diaphragm 
is virtually the only active muscle. Apnoeas occur when the airway 
at the back of the throat is sucked closed when breathing in during 
sleep. When the person is awake, this tendency is overcome by 
the action of opening muscles of the upper airway (the genioglos­
sus and palatal muscles), but these become hypotonic during sleep 
(Fig. 28.27). Partial narrowing results in snoring, complete occlusion 
causes apnoea and critical narrowing causes hypopnoeas. Apnoea 
leads to hypoxia and increasingly strenuous respiratory efforts until 
the patient overcomes the resistance. The combination of central 
hypoxic stimulation and the effort to overcome obstruction wakes 
the patient from sleep. These awakenings are so brief that patients 
remain unaware of them but may be woken hundreds of times per 
night, leading to sleep deprivation with consequent daytime sleepi­
ness and impaired intellectual performance.
Correctable factors occur in about one-­third of cases and 
include:
 • encroachment on pharynx - obesity, acromegaly, enlarged 
tonsils
 • nasal obstruction - nasal deformities, rhinitis, polyps, adenoids
 • respiratory depressant drugs - alcohol, sedatives, strong an­
algesics. 
Diagnosis
Relatives often provide a good history of the snore-silence-snore 
cycle. Individuals may complain of poor concentration and of waking 
feeling unrefreshed. The Epworth Sleepiness Scale (Box 28.29) is a 
measure of excessive daytime sleepiness and may prompt investi­
gation. The STOP BANG tool (Box 28.30) is also a useful screening 
tool and should flag appropriate patients to refer for further investi­
gation. It may help discriminate OSA from simple snoring. 
Investigations
If the diagnosis is suspected, further investigation is necessary to 
determine if there is sleep-­disordered breathing. Many of these 
investigations can be performed at home, using overnight pulse 
oximetry, and monitoring the pulse and the oxygen level. Oximetry 
Conditions in which 
ward-­based NIV is used
Clinical symptoms and biochemical markers
COPD, obesity
Respiratory rate >23 breaths/min
pH <7.35
PaCO2 >6.5 kPa
Neuromuscular 
disease
Respiratory illness with respiratory rate >20 
breaths/min if usual vital capacity <1 L, 
even if PaCO2 <6.5 kPa
pH <7.35
PaCO2 >6.5 kPa
Box 28.25 Indications for non-­invasive ventilation (NIV)
Absolute
 • Severe facial deformity
 • Facial burns
 • Asthma
 • Vomiting 
Relative
 • pH <7.15a
 • pH <7.25 and additional adverse featuresa
 • Glasgow Coma Scale score <8a
 • Confusion or agitationa
 • Cognitive impairment
   
aConsider NIV in a critical care setting.
Box 28.26 Contraindications to ward-­based non-­invasive 
ventilation (NIV)
Loud snoring
95
Daytime sleepiness
90
Unrefreshed sleep
40
Restless sleep
40
Morning headache
30
Nocturnal choking
30
Reduced libido
20
Morning ''drunkenness''
5
Ankle swelling
5
Box 28.28 Symptoms (%) of obstructive sleep apnoea
2
−
−
−
−
−
−
2
1RUPDO
2EVWUXFWLYHVOHHSDSQRHD
$
%
Fig. 28.27  Section through head, showing pressure changes in 
normal patients and those with obstructive sleep apnoea (OSA).  (A) 
There is a pressure drop during inspiration as air is sucked through the 
turbinates. Changes are shown in kPa. (B) In OSA this is sufficient to col­
lapse the pharynx (arrowed on right), obstructing inspiration.
Variable
Points on BODE index
0
1
2
3
FEV1 (% of predicted)
≥65
50-64
36-49
≤35
Distance walked in 
6 min (m)
≥350
250-349
150-249
≤149
MMRC dyspnoea 
scaleb
0-1
2
3
4
Body mass index
>21
≤21
Box 28.27 BODE indexa
aBody mass index, degree of airflow obstruction, dyspnoea and exercise 
capacity.
bScores on the modified Medical Research Council (MMRC) dyspnoea 
scale range from 0 to 4, a score of 4 indicating that the patient is 
breathless when dressing.', 4326),
   ('1a60a794-ebc4-5cdf-a6ea-ef9102b2c102', 'KUMAR_CLARK_10_2017', 'KC-C28', 962, 980, 0, '28
962  Respiratory disease 
will demonstrate desaturations in a cyclical manner, which will give 
a typical sawtooth appearance. The oximetry desaturation index 
(ODI) measures the number of desaturations per hour, which can 
determine the severity of sleep apnoea and correlates with the 
apnoea-hypopnea index (see later).
Overnight oximetry will not differentiate between central and 
obstructive apnoeas. Multichannel sleep studies (nocturnal polygra­
phy), which measure body posture and movements, breathing rate 
and electroencephalography alongside pulse oximetry, are used 
where the diagnosis is uncertain.
Severity is defined by the number of episodes of apnoea or 
hypopnea per hour, which is known as the apnoea-hypopnea 
index (AHI):
 • AHI <5: normal
 • AHI 5-15: mild OSA
 • AHI 15-30: moderate OSA
 • AHI >30: severe OSA. 
Management
Management consists of correction of treatable factors, including 
encouraging weight loss and alcohol reduction. Patients who have 
OSA with associated daytime somnolence should be offered con­
tinuous positive airway pressure (CPAP) during sleep. CPAP splints 
the upper airway such that it cannot occlude. It improves symp­
toms, quality of life, daytime alertness and survival. 
Chronic ventilatory failure
Ventilatory failure, also known as type II respiratory failure (see p. 
224), is a failure of alveolar ventilation with associated hypercapnia. 
This can be the sequela of a number of conditions that result in an 
imbalance of the resistive load in the lungs (Box 28.31). Symptoms 
of hypercapnia include morning headaches, daytime somnolence, 
confusion, memory impairment and unsteadiness. 
Domiciliary non-­invasive ventilation
Home mechanical ventilation can be considered if a patient has per­
sistent hypercapnia due to one of the conditions above. Patients 
typically use a portable ventilator overnight, which provides posi­
tive pressure support at different levels during inspiration and expi­
ration. Home mechanical ventilation has been shown to improve 
survival in COPD patients who have persistent type II respiratory 
failure following an acute admission. There are no randomized trials 
of NIV in kyphoscoliosis; however, survival curves show improved 
survival where NIV is offered. In patients with neuromuscular dis­
orders, home NIV has been shown to improve quality of life and 
prolong survival.
Further reading
Boucher RC. Muco-Obstructive Lung Diseases. New Engl J Med 2019; 
380:1941-1953.
Jones PW, Harding G, Berry P et al. Development and first validation of the 
COPD Assessment Test. Eur Respir J 2009; 34:648-654.
Murphy PB, Rehal S, Arbane G et al. Effect of home non-­invasive ventilation 
with oxygen therapy vs oxygen therapy alone on hospital readmission or death 
after an acute COPD exacerbation: a randomised controlled trial. JAMA 2017; 
317:2177-2186.
Suissa S and Drazen JM. Making sense of Triple Inhaled Therapy for COPD. 
New Engl J Med 2018; 1723-1724
Zeng Z, Yang D, Huang X et al. Effect of carbocisteine on patients with COPD: 
a systematic review and meta-­analysis. Int J Chron Obstruct Pulmon Dis 2017; 
12:2277-2283.
https://goldcopd.org/. Global Initiative for Chronic Obstructive Lung Disease 
(2019 Report).
https://www.brit-­thoracic.org.uk. British Thoracic Society guidelines for home 
oxygen use in adults (2015).
https://www.catestonline.org. COPD Assessment Test (CAT). 
How likely are you to doze off or fall asleep in the following situations, in 
contrast to just feeling tired? This refers to your usual way of life in recent 
times. Even if you have not done some of these things recently, try to work 
out how they would have affected you. Use the following scale to choose the 
most appropriate number for each situation.
0 = would never doze
1 = slight chance of dozing
2 = moderate chance of dozing
3 = high chance of dozing
Situation
Chance of dozing
Sitting and reading
_______________
Watching TV
_______________
Sitting and inactive in a public place 
(theatre or meeting)
_______________
As a passenger in a car for an hour 
without a break
_______________
Lying down to rest in the afternoon when 
circumstances permit
_______________
Sitting and talking to someone
_______________
Sitting quietly after lunch (without alcohol)
_______________
In a car, while stopped for a few minutes 
in the traffic
_______________
TOTAL
_______________
Normal <9
Excessive daytime somnolence >9 - causes include obstructive sleep 
apnoea. Other conditions causing excessive daytime somnolence include narco­
lepsy, restless leg syndrome and periodic limb movement disorder.
Box 28.29 Epworth sleepiness scale
Airflow obstruction
 • Chronic obstructive pulmonary disease 
Restrictive lung disease
 • Obstructive sleep apnoea/obesity hypoventilation syndrome
 • Kyphoscoliosis
 • Thoracoplasty 
Neuromuscular disease
 • Post-­polio syndrome
 • Diaphragm palsy
 • Motor neurone disease
 • Myotonic dystrophy 
Central causes
 • Brain injury
 • Multiple system atrophy
Box 28.31 Causes of chronic ventilatory failure
Question
Answer
Snoring - do you snore?
Yes/No
Tiredness - do you often feel tired, fatigued or sleepy?
Yes/No
Observed apnoeas
Yes/No
Pressure - do you have high blood pressure or are you 
on treatment for it?
Yes/No
Body mass index >35
Yes/No
Age >50 years
Yes/No
Neck size (≥male 43 cm, women ≥41 cm)
Yes/No
Gender - male
Yes/No
Box 28.30 STOP BANG tool
Obstructive sleep apnoea: low risk = yes to 0-2 questions, intermediate 
risk = yes to 3-4, high risk = yes to 5-8.', 5529),
   ('5bf820a7-7bac-52c5-8757-49796b093c5e', 'KUMAR_CLARK_10_2017', 'KC-C28', 963, 981, 0, '28
Respiratory Infection  963
SMOKING
Prevalence
Cigarette smoking is declining in the Western world but remains a 
leading cause of preventable death. The World Health Organization 
(WHO) predicts that tobacco is responsible for the death of 7 mil­
lion people each year. In 1974 in the UK, 51% of men and 41% 
of women smoked cigarettes - nearly half the adult population - 
whereas the annual population survey of 2015 showed that 17.2% 
of adults in the UK smoked. 
Toxic effects
Cigarette smoke contains polycyclic aromatic hydrocarbons and 
nitrosamines, which are potent carcinogens. Smokers have an 
increase in neutrophils and macrophages in the airways. These 
inflammatory cells release proteases that are capable of destroying 
elastin and lead to lung damage. Pulmonary epithelial permeability 
increases, even in symptomless cigarette smokers, and correlates 
with the concentration of carboxyhaemoglobin in blood. This altered 
permeability may allow easier access into blood for carcinogens. 
Dangers
Cigarette smoking is addictive and harmful to health (Box 28.32). 
Smoking 20 cigarettes daily for 20 years increases the lifetime risk 
of lung cancer by about ten times, compared to the risk in a life-­long 
non-­smoker. Smoking and asbestos exposure are synergistic risk 
factors for lung cancer, with a combined risk about 90 times that of 
unexposed non-­smokers.
Environmental tobacco smoke (''passive smoking'') has been 
shown to increase the frequency and severity of asthma attacks in 
children and may also raise the incidence of asthma. It is also asso­
ciated with a small but definite increase in lung cancer. Worldwide, 
second-­hand smoke was estimated to affect 40% of children, 33% of 
non-­smoking males and 35% of non-­smoking females in 2004. This 
caused 1% of all deaths worldwide and 0.7% of the total worldwide 
burden of disease in disability-­adjusted life years (DALYs). 
Smoking cessation
If the entire population could be persuaded to stop smoking, 
the effect on healthcare use would be enormous. National cam­
paigns, bans on advertising and a substantial increase in the cost 
of cigarettes are the best ways of achieving this at the popula­
tion level. Smoking bans in workplaces and public spaces have 
also helped. Meanwhile, active encouragement to stop smoking 
remains a useful approach for individuals. Smokers who want to 
quit should have access to smoking cessation clinics for behav­
ioural support. Nicotine replacement therapy (NRT) and bupropion 
are effective aids to smoking cessation in those smoking more 
than 10 cigarettes per day. Both should be used only in smok­
ers who commit to a target stop date, and the initial prescription 
should be for 2 weeks beyond the target stop date. NRT is the 
preferred choice; there is no evidence that combined therapy 
offers any advantage. Therapy should be changed after 3 months 
if abstinence is not achieved.
Varenicline is an oral partial agonist on the α4β2 subtype of the 
nicotinic acetylcholine receptor. It stimulates the nicotine receptor 
and reduces withdrawal symptoms and also the craving for ciga­
rettes. A 12-­week course doubles the chances of smoking cessa­
tion. Electronic cigarettes (battery-­operated vaporizers, e-­cigarettes) 
are useful alternatives to tobacco smoking and there is evidence 
that they may be helpful in smoking cessation, although evidence 
regarding the long term safety of vaping is awaited.
Further reading
Christiani DC. Vaping induce acute lung injury. N Engl J Med 2020; 382:960-962.
Colditz GA. Smoke alarm - tobacco control remains paramount. N Engl J Med 
2015; 372:665-666.
Gu D, Kelly TN, Wu X et al. Mortality attributable to smoking in China. N Engl J 
Med 2009; 360:150-159.
Oberg M, Jaakkola MS, Woodward A et al. Worldwide burden of disease from 
exposure to second-­hand smoke: a retrospective analysis of data from 192 
countries. Lancet 2008; 372:139-146.
Oncken C. Nicotine replacement for smoking cessation during pregnancy. N Engl 
J Med 2012; 366:846-847. 
RESPIRATORY INFECTION
Pneumonia
Pneumonia is defined as inflammation of the substance of the 
lungs. It is usually caused by bacteria but can also be caused by 
viruses and fungi. Clinically, it usually presents as an acute illness 
with cough, purulent sputum, breathlessness and fever, together 
with physical signs or radiological changes compatible with con­
solidation of the lung (Fig. 28.28). However, it can present with more 
subtle symptoms, particularly in the elderly.
Pneumonia is usually classified by the setting in which the 
patient has contracted the infection, for example:
 • community-­acquired pneumonia in a person with no underly­
ing immunosuppression or malignancy
 • hospital-­acquired pneumonia (sometimes called ''healthcare-­
associated pneumonia'', reflecting the role of other institutions 
such as nursing homes)
 • aspiration pneumonia, associated with the aspiration of food 
material or stomach contents into the lungs, and caused by im­
paired swallowing
 • pneumonia in immunocompromised patient, acquired 
through either a genetic defect, immunosuppressive medication 
or acquired immunodeficiency, as in human immunodeficiency 
virus (HIV) infection
 • ventilator-­acquired pneumonia, acquired through mechanical 
ventilation on a critical care unit.
Community-­acquired pneumonia
Community-­acquired pneumonia (CAP) occurs across all ages but is 
more common at the extremes of age. Streptococcus pneumoniae 
General
 • Lung cancer
 • Chronic obstructive pulmonary disease (COPD)
 • Carcinoma of the oesophagus
 • Ischaemic heart disease
 • Peripheral vascular disease
 • Bladder cancer
 • An increase in abnormal spermatozoa
 • Memory problems 
Maternal smoking
 • A decrease in birth weight of the infant
 • An increase in fetal and neonatal mortality
 • An increase in asthma 
Passive smoking
 • Risk of asthma, pneumonia and bronchitis in infants of smoking parents
 • An increase in cough and breathlessness in smokers and non-­smokers 
with COPD and asthma
 • An increase in cancer risk
Box 28.32 Dangers of cigarette smoking', 6123),
   ('45737756-dbe7-588c-ae16-ea806b31f983', 'KUMAR_CLARK_10_2017', 'KC-C28', 964, 982, 0, '28
964  Respiratory disease 
is the most common cause overall; however, in 30-50% of cases no 
organism is identifiable, while in about 20% more than one organ­
ism is present. Infection can be localized, when the whole of one or 
more lobes is affected (''lobar pneumonia''), or diffuse, when the lob­
ules of the lung are mainly affected, often due to infection centred 
on the bronchi and bronchioles (''bronchopneumonia''). Factors that 
increase the risk of developing CAP are shown in Box 28.33. 
Clinical features
The clinical presentation varies according to the immune state of the 
patient and the infecting agent. Features include:
 • a dry or productive cough, sometimes with haemoptysis
 • breathlessness
 • fevers, which, if swinging, may indicate empyema (see p. 965)
 • chest pain may be experienced, commonly pleuritic in nature 
and due to inflammation of the pleura; a pleural rub may be 
heard early on in the illness
 • extrapulmonary features (Box 28.34).
In the elderly, CAP can present with confusion or non-­specific 
symptoms such as recurrent falls. CAP should always be consid­
ered in the differential diagnosis of sick elderly patients, given their 
frequently atypical presentation. 
Initial assessment
The type and extent of investigations depend on the severity of the 
illness, which also guides where the patient should be managed 
and predicts their outcome. Diagnostic microbiological tests are 
not needed in mild infection, which should be treated at home with 
standard oral antibiotics (amoxicillin, or clarithromycin for those 
with a history of penicillin allergy). Where patients have mild dis­
ease, chest X-­ray is not routinely recommended unless they fail to 
improve after 48-72 hours.
Severity is commonly assessed by the CURB-­65 or the CRB-­
65 score; the CRB-­65 score is used in the community where the 
serum urea level is not usually available (Box 28.35). These give a 
guide to the likely risk of fatal outcome but antibiotic choice must 
always be tempered by clinical assessment and judgement, taking 
into account other factors associated with increased rates of mor­
tality (see Box 28.27). 
Investigations
All patients admitted to hospital with suspected CAP should have a 
chest X-­ray, blood tests and microbiological tests.
Chest X-­ray
Radiological abnormalities can lag behind clinical signs. A normal 
chest X-­ray on presentation should be repeated after 2-3 days if 
CAP is suspected clinically. The chest X-­ray must be repeated 6 
Fig. 28.28  Chest X-­ray showing lobar pneumonia.
 • Age: <16 or >65 years
 • Co-­morbidities: HIV infection, diabetes mellitus, chronic kidney disease, 
malnutrition, recent viral respiratory infection
 • Other respiratory conditions: cystic fibrosis, bronchiectasis, chronic 
obstructive pulmonary disease, obstructing lesion (endoluminal cancer, 
inhaled foreign body)
 • Lifestyle: cigarette smoking, excess alcohol, intravenous drug use
 • Iatrogenic: immunosuppressant therapy (including prolonged 
corticosteroids)
Box 28.33 Risk factors for community-­acquired pneumonia
 • Myalgia, arthralgia and malaise are common, particularly in infections 
caused by Legionella and Mycoplasma
 • Myocarditis and pericarditis are cardiac manifestations of infection, 
most commonly in Mycoplasma pneumonia
 • Headache is common in Legionella pneumonia. Meningoencephalitis 
and other neurological abnormalities also occur but are much less 
­common
 • Abdominal pain, diarrhoea and vomiting are common. Hepatitis can 
be a feature of Legionella pneumonia
 • Labial herpes simplex reactivation is relatively common in pneumo­
coccal pneumonia
 • Other skin rashes, such as erythema multiforme and erythema 
nodosum, are found in Mycoplasma pneumonia. Stevens-Johnson 
syndrome (see p. 697) is a rare and potentially life-­threatening 
complication of pneumonia
Box 28.34 Extrapulmonary features of community-­acquired 
pneumonia
CURB-­65
C: Confusion present (abbreviated mental test score <8/10)
U: (plasma) Urea level >7 mmol/L
R: Respiratory rate >30 breaths/min
B: systolic Blood pressure <90 mmHg; diastolic <60 mmHg
65: age >65
1 point for each of the above:
 • Score 0-1: Treat as outpatient
 • Score 2: Admit to hospital
 • Score 3+: Often require care in intensive treatment unit
Mortality rates increase with increasing score. 
Other markers
 • Chest X-­ray: more than one lobe involved
 • PaO2: <8 kPa
 • Low albumin: <35 g/L
 • White cell count: <4 × 109/L or >20 × 109/L
 • Blood culture: positive
 • Other co-­morbidities
 • Absence of fever in the elderly
Box 28.35 CURB-­65 score and other markers of severe 
community-­acquired pneumonia', 4678),
   ('78cbd381-63bf-580f-b6b9-5f3deb58759d', 'KUMAR_CLARK_10_2017', 'KC-C28', 965, 983, 0, '28
Respiratory Infection  965
weeks later to rule out an underlying bronchial malignancy causing 
pneumonia due to bronchial obstruction. 
Blood tests
Full blood count, serum creatinine and electrolytes, biochemistry 
and C-­reactive protein (CRP) are helpful.
 • Strep. pneumoniae. White cell count is usually >15 × 59/L (90% 
leucocytosis neutrophils). Inflammatory markers are significantly 
elevated: erythrocyte sedimentation rate (ESR) >100 mm/h; CRP 
>100 mg/L.
 • Mycoplasma. White cell count is usually normal. In the presence 
of anaemia, haemolysis should be ruled out (direct Coombs'' test 
and measurement of cold agglutinins, see p. 965).
 • Legionella. There is lymphopenia without marked leucocytosis, 
hyponatraemia, hypoalbuminaemia and high serum levels of 
liver aminotransferases. 
Other tests
 • Sputum culture and blood cultures are required for all patients 
who have moderate to severe CAP, ideally before antibiotics are 
administered. In Strep. pneumoniae infection, positive blood 
cultures indicate more severe disease with greater mortality.
 • Arterial blood gas analysis is necessary if oxygen saturation is 
<94%.
 • An HIV test should be offered to all patients with pneumonia 
since it is a common initial presenting illness in previously undi­
agnosed HIV infection. 
General management
Initial management and assessment should follow the guidelines 
for management of sepsis (see p. 157), particularly when a patient 
appears to have a moderate to severe pneumonia. In general:
 • Oxygen. Supplemental oxygen should be administered to main­
tain saturations between 94% and 98% (provided the patient is 
not at risk of carbon dioxide retention, due to loss of hypoxic 
drive in COPD). In patients with known COPD, oxygen satura­
tions should be maintained between 88% and 92%.
 • Intravenous fluids. These are required in hypotensive patients 
showing any evidence of volume depletion and hypotension.
 • Antibiotics. The first dose of antibiotic should be administered 
within 1 hour of identifying any high-­risk criteria and treatment 
should not be delayed while investigations are awaited. Paren­
teral antibiotics should be switched to oral once the temperature 
has settled for a period of 24 h, provided there is no contraindi­
cation to oral therapy. If patients fail to respond to initial treat­
ment, microbiological advice should be sought and alternative 
diagnoses considered. The antibiotic regimen should be adjust­
ed specifically once culture and sensitivity results are available 
(Fig. 28.29).
 • Thromboprophylaxis. If the patient is admitted for >12 h, sub­
cutaneous low-­molecular-­weight heparin should be prescribed 
and thromboembolus deterrent (TED) stockings should be fitted, 
unless contraindications exist.
 • Physiotherapy. Chest physiotherapy is not needed unless spu­
tum retention is an issue.
 • Nutritional supplementation. Need is assessed by a dietician, 
particularly in severe disease.
 • Analgesia. Simple analgesia, such as paracetamol or an NSAID, 
helps treat pleuritic pain, thereby reducing the risk of further 
complications due to restricted breathing because of pain (e.g. 
sputum retention, atelectasis or secondary infection).
Causes of a slow-­resolving pneumonia are outlined in Box 28.36. 
Prevention
Cigarette smoking is an independent risk factor for CAP; if the 
patient still smokes, cessation advice and support should be given.
Vaccination against influenza is recommended for at-­risk groups. 
All patients over the age of 65 who have not previously been vac­
cinated and are admitted with CAP should have the pneumococcal 
vaccine before discharge from hospital. 
Complications of pneumonia
See Box 28.37.
Parapneumonic effusion and empyema
Pleural effusions are common with pneumonia and complicate 
around one-­third to one-­half of cases of CAP. The majority of these 
are simple exudative effusions but empyema may also develop 
(purulent fluid in the pleural space). Early indications of empyema 
are ongoing fever and rising or persistently elevated inflammatory 
markers, despite appropriate antibiotic therapy.
Pleural aspiration should be performed under ultrasound guid­
ance to make a diagnosis and fluid sent for Gram stain, culture, fluid 
protein, glucose and LDH (with comparison to serum levels). Light''s 
criteria (see p. 973) can be applied to assess whether an effusion 
is transudative or exudative. An exudative effusion with pleural fluid 
pH of <7.2 is strongly suggestive of empyema. Pathogens are often 
detectable; sensitivity analysis will help guide antimicrobial therapy.
If an empyema develops, the fluid should be urgently drained 
to prevent further complications, such as development of a thick 
Incorrect or incomplete antimicrobial treatment
 • Underlying antibiotic resistance
 • Inadequate dose/duration
 • Non-­adherence
 • Malabsorption 
Complication of community-­acquired pneumonia
 • Parapneumonic pleural effusion (exudative)
 • Empyema
 • Lung abscess 
Underlying neoplastic lesion or other lung disease
 • Obstructing lesion
 • Bronchoalveolar cell carcinoma
 • Bronchiectasis
 • Tuberculosis 
Alternative diagnosis
 • Pulmonary thromboembolic disease
 • Cryptogenic organizing pneumonia
 • Eosinophilic pneumonia
 • Pulmonary haemorrhage
Box 28.36 Causes of slow-­resolving pneumonia
General
 • Respiratory failure
 • Sepsis - multisystem failure 
Local
 • Pleural effusion
 • Empyema
 • Lung abscess
 • Organizing pneumonia
Box 28.37 Complications of pneumonia', 5543),
   ('6c057bea-4fa4-5ab7-9af9-bde1d8aa51bf', 'KUMAR_CLARK_10_2017', 'KC-C28', 966, 984, 0, '28
966  Respiratory disease 
pleural rind or prolonged hospital admission. The presence of 
empyema further increases mortality risk. The duration of antibiotic 
administration will usually need to be extended. Whenever possible, 
the choice of antimicrobial should be guided by the results of cul­
tures. Thoracic surgical intervention is necessary in severe cases. 
Lung abscess
This term is used to describe severe localized suppuration within 
the lung associated with cavity formation visible on the chest X-­ray 
or CT scan, often with a fluid level (which always indicates an air-liq­
uid interface). There are several causes of lung abscess (Box 28.38). 
Clinical features usually include persisting or worsening pneumonia 
associated with the production of large quantities of sputum, which 
is often foul-­smelling owing to the growth of anaerobic organisms. 
There is usually a swinging fever; malaise and weight loss frequently 
occur. There may be few signs on physical examination, although 
clubbing occurs in chronic suppuration. Patients have a normocytic 
anaemia and raised inflammatory markers (ESR/CRP). CT scanning 
is essential and bronchoscopy can be undertaken to obtain samples 
or remove foreign bodies. Treatment should be guided by available 
culture results or clinical judgement, and is often prolonged (4-6 
weeks). Surgical drainage is sometimes necessary. 
Pneumonia in other settings
Hospital-­acquired pneumonia
Hospital-­acquired pneumonia (HAP) is defined as new onset of 
cough with purulent sputum, along with a compatible X-­ray dem­
onstrating consolidation, in patients who are beyond 2 days of their 
/RZPRUWDOLW\ULVN
&5%

+RPHFDUHDSSURSULDWH
,QFUHDVHGPRUWDOLW\ULVN
&5%
²
+RVSLWDOUHIHUUDOIRUDVVHVVPHQW
GRVHUXPXUHD
&DOFXODWH&85%±
+LJKPRUWDOLW\ULVN
&5%
²
8UJHQWUHIHUUDOWRKRVSLWDOIRU
DVVHVVPHQWDQGDGPLVVLRQ
&85%²²
5HIHUWRVHQLRUFOLQLFLDQDQG
,78IRUXUJHQWDVVHVVPHQW
&85%²PRUWDOLW\
 0D\EHVXLWDEOHIRUVKRUWVWD\DPEXODWRU\FDUH
 1RPLFURELRORJLFDOGLDJQRVWLFWHVWVQHFHVVDU\
 XQOHVVRXWEUHDNVXVSHFWHGRU0\FRSODVPD
HSLGHPLF
 2UDODPR[LFLOOLQPJïGDLO\
 25RUDOFODULWKURP\FLQPJïGDLO\
 25GR[\F\FOLQHPJGDLO\
  PJLQLWLDOORDGLQJGRVH
  ,)SHQLFLOOLQDOOHUJLF
&85%²²
 *LYHDQWLELRWLFVDVVRRQDV
 SRVVLEOH
 &RDPR[LFODYJïGDLO\
 LY3/86
 FODULWKURP\FLQPJïGDLO\
 LYIOXRURTXLQRORQHLI
 OHJLRQQDLUH·VGLVHDVHVXVSHFWHG
 $OWHUQDWLYH
   3HQLFLOOLQDOOHUJ\
   LYFHSKDORVSRULQ
   HJFHIWULD[RQHJGDLO\3/86
   FODULWKURP\FLQPJïGDLO\
   LYEHQ]\OSHQLFLOOLQJïGDLO\
   25KRXUO\3/86
   DIOXRURTXLQRORQH
   OHYRIOR[DFLQRUPR[LIOR[DFLQ
&85%²²²PRUWDOLW\
 %ORRGFXOWXUHV
 6SXWXPLIQRDQWLELRWLFV
 3QHXPRFRFFDODQWLJHQ
 /HJLRQHOODDQWLJHQ
 FXOWXUHLISRVLWLYH
 6HURORJ\DQGYLUDO3&5
 FRQVLGHUFRQYDOHVFHQWVHURORJ\
&85%²PRUWDOLW\
 %ORRGFXOWXUHV
 6SXWXPLIQRDQWLELRWLFV
 3QHXPRFRFFDODQWLJHQLI
 VXVSHFWHGFOLQLFDOO\
 FXOWXUHLISRVLWLYH
 6HURORJ\RU3&5LIHSLGHPLF
 $PR[LFLOOLQ²PJïGDLO\
 3/86FODULWKURP\FLQPJïGDLO\
 RUDOO\LYLIRUDOQRWSRVVLEOH
 3HQLFLOOLQDOOHUJ\
 GR[\F\FOLQHPJGDLO\
 PJLQLWLDOORDGLQJGRVH
 25OHYRIOR[DFLQPJïGDLO\RUDOO\
 25PR[LIOR[DFLQPJGDLO\RUDOO\
1RQHHGIRUPLFURELRORJLFDO
GLDJQRVWLFWHVWV
2UDODPR[LFLOOLQPJïGDLO\
25RUDOFODULWKURP\FLQPJïGDLO\
25GR[\F\FOLQHPJGDLO\
 PJLQLWLDOORDGLQJGRVH
 ,)SHQLFLOOLQDOOHUJLF
Fig. 28.29  Algorithm for the assessment and treatment of community-­acquired 
pneumonia.  CRB, confusion, respiratory rate, blood pressure (CURB includes urea); ITU, intensive 
treatment unit; PCR, polymerase chain reaction.', 3840),
   ('5583ce20-bbb5-5cb7-bb20-28b0f9104d18', 'KUMAR_CLARK_10_2017', 'KC-C28', 967, 985, 0, '28
Respiratory Infection  967
initial admission to hospital or who have been in a healthcare setting 
within the last 3 months (including nursing or residential homes, as 
well as acute care facilities such as hospitals). HAP is the second 
most common form of hospital-­acquired infection after urinary tract 
infections and carries a significant mortality risk, particularly in the 
elderly or those with co-­morbidities such as stroke, respiratory dis­
ease or diabetes. In HAP, the causative organisms differ from those 
causing CAP (Box 28.39). Viral or fungal pathogens only affect 
immunocompromised hosts. 
Ventilator-­associated pneumonia
This occurs in the context of mechanical ventilation in a critical care 
setting. Often multidrug-­resistant Gram-­negative organisms (such as 
Acinetobacter baumanii) are responsible, requiring careful selection of 
an appropriate antibiotic in association with a clinical microbiologist. 
Aspiration pneumonia
Acute aspiration of gastric contents into the lungs can produce an 
extremely severe and sometimes fatal illness owing to the intense 
destructiveness of gastric acid. This can complicate anaesthesia, 
particularly during pregnancy (Mendelson''s syndrome). Because of 
the bronchial anatomy, the most usual sites for aspirated material 
to end up are the right middle lobe and the apical or posterior seg­
ments of the right lower lobe. Persistent pneumonia is often due to 
anaerobes and may progress to lung abscess or even bronchiec­
tasis if protracted. It is vital to identify any underlying problem, as 
aspiration will recur without appropriate corrective measures.
Treatment should be directed specifically against positive cultures if 
available. If not, then co-­amoxiclav is used for mild to moderate disease, 
which covers Gram-­negative and anaerobic bacteria. Treatment needs 
to be escalated when there is a lack of response or cases are severe. 
Pneumonia in immunocompromised patients
Patients who are immunosuppressed (either iatrogenically or due 
to a defect in host defences) are at risk not only from all the usual 
organisms that can cause pneumonia but also from opportunistic 
pathogens that would not be expected to cause disease. These 
opportunistic pathogens can be commonly occurring microorgan­
isms (that are ubiquitous in the environment) or bacteria, viruses 
and fungi that are less common (see Box 37.21). The symptom pat­
tern may resemble CAP or be more non-­specific. A high degree 
of clinical suspicion is therefore necessary when assessing an ill 
patient who is immunocompromised.
Pneumocystis jirovecii pneumonia
Pneumocystis pneumonia is one of the most common opportunistic 
infections encountered in clinical practice. It affects patients on immu­
nosuppressant therapy, such as long-­term corticosteroids, mono­
clonal antibodies or methotrexate for autoimmune disease; those on 
anti-­rejection medication after a solid organ or haemopoietic stem 
cell transplantation; and those infected with HIV. Individuals with CD4 
counts of less than 200/mm3 are at particular risk. Pneumocystis jir­
ovecii is found in the air, and pneumonia arises from re-­infection rather 
than reactivation of persisting organisms acquired in childhood.
Clinically, the pneumonia is associated with a high fever, breath­
lessness and dry cough. A characteristic feature on examination is 
rapid desaturation on exercise or exertion. The typical radiographic 
appearance is one of diffuse bilateral alveolar and interstitial shadow­
ing beginning in the perihilar regions and spreading out in a butterfly 
pattern. Other chest X-­ray appearances include localized infiltration, 
nodules, cavitation or a pneumothorax. Empirical treatment is justi­
fied in very sick high-­risk patients; wherever possible, however, the 
diagnosis should be confirmed by indirect immunofluorescence on 
induced sputum or bronchoalveolar lavage fluid. First-­line treatment 
of Pneumocystis pneumonia is with high-­dose co-­trimoxazole (see p. 
1443), with adjunctive corticosteroids in patients with HIV infection.
Further reading
British Thoracic Society. 2015-­Annotated BTS guideline for the management of 
CAP in adults (2009): Summary of recommendations; BTS 2015; https://brit.tho
racic.org.uk/guidelines-­and-­quality-­standards/community-­acquired-­pneumonia-­
in-­adults-­guidance/annotated-­bts-­guideline-­for-­the-­management-­of-­cap-­in-­
adults-­2014/.
Jain S, Self WH, Wunderink S et al. Community-­acquired pneumonia requiring 
hospitalization among US adults. N Engl J Med 2015; 373:415-427.
Lim WS, Baudouin SV, George RC et al. British Thoracic Society Guidelines 
for the management of community-­acquired pneumonia in adults: update 2009. 
Thorax 2009; 64(Suppl III):iii1-iii55.
Loke YK, Kwok CS, Niruban A et al. Value of severity scales in predicting 
mortality from community-­acquired pneumonia: systematic review and meta-­
analysis. Thorax 2010; 65:884-890.
Mansell A, Niederman LA. Aspiration pneumonia. N Engl J Med 2019; 380:651-
663.
Musher DM, Thorner AR. Community acquired pneumonia. N Engl J Med 2014; 
371:1619-1628.
National Institute for Health and Care Excellence. Clinical Guideline 191: 
Pneumonia in Adults: Diagnosis and Management. NICE 2014; https://www.nice.
org.uk/guidance/cg191.
Wunderick RG, Waterer G. Advances in the causes and management of 
community acquired pneumonia in adults. BMJ 2017; 358:j2471. 
Tuberculosis
Tuberculosis (TB) is one of the world''s most common infectious dis­
eases. It is caused by the bacterium Mycobacterium tuberculosis, 
which comes from the large Mycobacteriaceae family, members of 
which include M. leprae. It is estimated that one-­third of the world''s 
population is infected with tuberculosis (see also p. 503), with the 
majority of cases (around 65%) seen in Africa and Asia. There is 
Causes
 • Aspiration pneumonia
 • Tuberculosis
 • Staphylococcus aureus or Klebsiella pneumoniae
 • Septic emboli usually containing staphylococci
 • Inadequately treated community-­acquired pneumonia
 • Spread from an amoebic liver abscess
 • Bronchial obstruction by an endoluminal cancer
 • Foreign body inhalation 
Common causative organisms
 • Klebsiella pneumoniae
 • Staphylococcus aureus
 • Gram-­negative enteric bacilli
 • Mycobacterium tuberculosis
 • Streptococcus milleri
 • Anaerobic bacteria (post aspiration)
 • Haemophilus influenzae
Box 28.38 Causes of lung abscess and causative 
organisms
 • Gram-­negative bacteria (Pseudomonas spp., Escherichia spp., Klebsiella 
spp.)
 • Anaerobic bacteria (Enterobacter spp.)
 • Staphylococcus aureus (including meticillin-­resistant Staph. aureus)
 • Acinetobacter spp.
Box 28.39 Organisms implicated in hospital-­acquired 
pneumonia', 6757),
   ('0f040d32-aac3-5405-b912-cf1320fe23e6', 'KUMAR_CLARK_10_2017', 'KC-C28', 968, 986, 0, '28
968  Respiratory disease 
a growing incidence of multidrug-­resistant and extremely drug-­
resistant strains, which, together with HIV co-­infection, places a 
huge health burden on resource-­poor nations, with a high mortality 
from the two coexistent diseases. TB was responsible for 1.6  million 
deaths worldwide in 2017 and 20% of these were in HIV co-­infected 
individuals. There are a number of factors affecting the prevalence 
and risk of developing TB (Box 28.40).
Pathogenesis
M. tuberculosis is an aerobic, intracellular pathogen. Due to their 
relative impermeability to acid-­based dyes in the laboratory, these 
organisms are often termed ''acid-­fast bacilli''. TB is an airborne 
infection spread by coughing via respiratory droplets. Only a small 
number of bacteria need to be inhaled for infection to develop, but 
not all those who are infected develop active disease.
Primary tuberculosis
''Primary TB'' describes the first infection with TB. When the bacteria 
reach the alveolar macrophages, they are ingested and the subse­
quent inflammatory reaction results in tissue necrosis and formation 
of a granuloma. These granulomatous lesions consist of a central 
area of necrotic material called caseation, surrounded by epithelioid 
cells and Langhans giant cells.
Subsequently, the caseated areas heal completely and many 
become calcified. Some of these calcified nodules contain bacteria, 
which are contained by the immune system (and the hypoxic acidic 
environment created within the granuloma) and are capable of lying 
dormant for many years. This is known as the primary focus or the 
''Ghon focus'' of the disease. On a chest X-­ray, the Ghon focus can 
be evident as a small, calcified nodule.
On initial contact with infection, less than 5% of patients 
develop active disease. This increases to 10% within the first year 
of exposure. 
Reactivation tuberculosis
In the majority of people who are infected by Mycobacterium spp., 
the immune system contains the infection and the patient develops 
cell-­mediated immune memory of the bacteria. This is termed ''latent 
TB''. The majority of active TB cases are due to reactivation of latent 
infection, where the initial contact usually occurred many years or 
decades earlier. Most patients are young and previously healthy but 
may have one or more of risk factors implicated in the development 
of active disease (Box 28.41). In patients with HIV infection, newly 
acquired TB is also common. The majority of active TB occurs in the 
lung, but extrapulmonary infection occurs with spread to the lymph 
nodes, particularly the cervical and intrathoracic chains, where it 
causes active disease in 20-25% (UK figures) and also via the blood­
stream to more distant sites such as the brain, bones and skin. 
Clinical features and diagnosis
The cardinal symptoms of TB are cough, haemoptysis and the sys­
temic symptoms of fevers, night sweats and weight loss. However, 
in extrapulmonary sites, respiratory symptoms are often absent, 
and the systemic symptoms are often ignored by patients and med­
ical practitioners alike.
In all cases of suspected TB, it is essential, depending on the site 
of disease, to obtain sputum, biopsy samples or fluid for micros­
copy, smear and culture, to obtain information on sensitivities. Tis­
sue samples should also be sent for histopathological examination, 
either dry or in saline.
Pulmonary TB
Patients are frequently symptomatic with a productive cough and, 
occasionally, haemoptysis, along with systemic symptoms. Where 
there is laryngeal involvement, a hoarse voice and a severe cough 
are found. If disease involves the pleura, then pleuritic pain is a fre­
quent presenting complaint.
The chest X-­ray (Fig. 28.30) can show consolidation with or 
without cavitation, pleural effusion, or thickening or widening of the 
mediastinum caused by hilar or paratracheal adenopathy.
Contact with high-­risk groups
 • Origination from a high-­incidence country (defined as >40/100 000)
 • Frequent travel to high-­incidence areas 
Immune deficiency
 • HIV infection
 • Corticosteroids or immunosuppressant therapy
 • Chemotherapeutic drugs
 • Nutritional deficiency (vitamin D)
 • Diabetes mellitus
 • Chronic kidney disease
 • Malnutrition/body weight >10% below ideal body weight 
Lifestyle factors
 • Drug/alcohol misuse
 • Homelessness/hostels/overcrowding
 • Prison inmates 
Genetic susceptibility
 • Twin studies of gene polymorphisms
Box 28.40 Factors affecting prevalence and risk of develop­
ing tuberculosis in the developed world
 • HIV co-­infection
 • Immunosuppressant therapy (chemotherapy/monoclonal antibody 
treatment), including corticosteroids
 • Diabetes mellitus
 • End-­stage chronic kidney disease
 • Malnutrition
 • Ageing
Box 28.41 Factors implicated in the reactivation of latent 
tuberculosis
Fig. 28.30  Chest X-­ray demonstrating patchy right mid and up­
per zone consolidation and a cavity at the right apex in a patient 
with tuberculosis.', 5014),
   ('403aab20-bb95-5b85-a79b-ee4b9cdb9769', 'KUMAR_CLARK_10_2017', 'KC-C28', 969, 987, 0, '28
Respiratory Infection  969
Serial sputum samples should be collected on at least three 
occasions (ideally, first thing in the morning); if the patient is unable 
to produce sputum, it may be necessary to organize an induced 
sputum or perform bronchoscopy to obtain samples.
Patients whose sputum is smear-­positive for TB are consid­
ered to be infectious and should be isolated in hospital. Those 
who are smear-­negative but subsequently culture-­positive are 
less infectious and generally so not need to be isolated, although 
care should be taken when contacts include immunocompromised 
individuals. 
Lymph node TB
The lymph nodes are the second most commonly affected organs. 
Extrathoracic nodes are more commonly involved than intratho­
racic or mediastinal. Usually, presentation is with firm, non-­tender 
enlargement of a cervical or supraclavicular node. The node 
becomes necrotic centrally and can liquefy and be fluctuant if 
peripheral. The overlying skin is frequently indurated or there can 
be sinus tract formation with purulent discharge, but characteristi­
cally there is no erythema (''cold abscess'' formation). Nodes can 
typically be enlarged for several months prior to diagnosis. On CT 
imaging, the central area appears necrotic (Box 28.42). Samples 
should be obtained via either ultrasound-­guided fine needle aspira­
tion (FNA), core biopsy or, if necessary, removal of a whole node. 
All samples must be sent for AFB smear and culture, and cancer 
should be excluded on cytology. EBUS can be used to biopsy intra­
thoracic nodes. 
Other forms of TB
Gastrointestinal TB
See page 1195. 
TB of bone and spine
See pages 455 and 484. 
Miliary TB
Miliary disease occurs through haematogenous spread of the bacilli 
to multiple sites, including the central nervous system (CNS) in 
20% of cases. It often presents with systemic symptoms and the 
chest X-­ray demonstrates multiple nodules, which appear like millet 
seeds: hence the term ''miliary''.
Other findings are liver and splenic microabscesses with 
deranged liver enzymes, cholestasis and gastrointestinal symp­
toms. All patients should have brain imaging (MRI), to look for evi­
dence of cerebral disease, which can present as an asymptomatic 
brain tuberculoma. 
Central nervous system TB
See page 870. 
Pericardial TB
See page 1126. 
Skin
See page 671. 
Microbiological diagnosis
Once samples have been taken, the rapid identification of the pres­
ence of mycobacterium by stains is essential and should be per­
formed within 24 hours; culture of the sample allows determination 
of the antibiotic sensitivity of the infecting strain.
Stains
Auramine-rhodamine staining is more sensitive (though less spe­
cific) than Ziehl-Neelsen; as a result, it is more widely used. It 
requires fluorescence microscopy and highlights bacilli as yellow-
orange on a green background. 
Culture
The majority of the developed world uses liquid/broth culture of 
mycobacteria in addition to solid media (Lowenstein-Jensen slopes 
or Middlebrook agar), as time to culture is shorter than for solid 
culture (1-3 weeks compared with 3-8 weeks). Using liquid culture 
in the presence of antimycobacterial drugs (usually first-­line ther­
apy) establishes the drug sensitivity for that strain and usually takes 
approximately 3 weeks. 
Nucleic acid amplification and polymerase chain 
reaction
Nucleic acid amplification testing (NAAT) is increasingly used 
for rapid identification of MTb complex and is useful in differen­
tiating between M. tuberculosis complex and non-­tuberculous 
mycobacteria, as well as identifying TB in smear-­negative sputum 
specimens. It works by using the polymerase chain reaction (PCR) 
to replicate and then identify mycobacterium DNA. Culture and 
staining are still necessary and should not be replaced by PCR. 
PCR is useful only at the initial stage of diagnosis, as it frequently 
remains positive despite treatment, due to the detection of dead 
organisms.
The identification of mycobacterial DNA is useful in facilitating 
rapid commencement of treatment and also rapid identification 
of drug resistance. Genetic mutations in bacterial DNA conferring 
rifampicin resistance are highly predictive of multidrug resistance. 
The development of a highly specific probe designed to detect this 
mutation thereby allows efficient identification of resistant disease 
and commencement of appropriate therapy sooner than waiting for 
cultures to complete (which may take up to 8 weeks).
Commercial kits, such as GeneXpert, are available that can reli­
ably perform molecular testing in the field and take less than 2 hours 
to complete; they are now widely used in low-­ and middle-­income 
countries to detect genetic mutations associated with rifampicin 
resistance.
More recently, in the UK, whole-­genome sequencing (WGS) has 
begun to be used on a routine basis to identify different strains of 
mycobacterium and also detect drug resistance. This will start to 
replace routine culture and phenotypic testing in the near future. 
Management
All patient should have routine blood tests and a viral hepatitis 
screen, and be offered an HIV test before treatment. Patients with 
active viral hepatitis are much more likely to develop a fatal drug-­
induced hepatitis and need careful monitoring and counselling. 
Those with fully sensitive TB require 6 months of treatment; the 
exception is TB infection of the CNS, for which the recommended 
duration is at least 12 months. Isoniazid, rifampicin, pyrazinamide 
and ethambutol are the first-­line TB drugs, known as quadruple 
therapy. In CNS and pericardial disease, corticosteroids are used 
as an adjunct at treatment initiation to reduce long-­term com­
plications. Box 28.43 summarizes the standard recommended 
regimens.
Enhanced case management, together with directly observed 
therapy (DOT), is recommended where there are concerns about 
adherence to treatment or difficulties in taking medication (Box 
28.44).', 5980),
   ('6a5fbdc4-7d8e-525a-9b1b-f79234c0d970', 'KUMAR_CLARK_10_2017', 'KC-C28', 970, 988, 0, '28
Radiology
Investigations
Pulmonary, pleural and laryngeal TB
Chest X-­ray of patient with suspected pulmonary TB
Smear and culture of:
Sputum (≥2 samples increase diagnostic yield)
Induced sputum (inhaled hypertonic saline, which induces coughing): 
diagnostic yield comparable to bronchoscopic samples
Bronchoalveolar lavage fluid if cough unproductive and induced sputum 
not possible
Aspiration of pleural fluid and pleural biopsy
Gastric aspirates - can be useful in paediatric disease
Nasoendoscopic or bronchoscopic examination/biopsy of vocal cords 
with biopsy for smear/culture and histology in laryngeal disease
Miliary TB
Chest X-­ray of patient with miliary pulmonary changes
Blood cultures
Bronchoalveolar lavage fluid (usually smear-­negative but culture-­positive)
MRI head followed by lumbar puncture should be performed in all cases, 
unless contraindicated, to assess for central nervous system involve­
ment (affects treatment duration), and sampling of other involved 
organs is often necessary
Central nervous system TB
MRI head of patient with lesion in right cerebellum
Ensure that patient and scans are discussed at neurology/neurosurgery 
MDT
Consider brain biopsy if concerns about diagnosis
Lumbar puncture if no contraindication - characteristics:
CSF protein may be very high (usually >2-3 g/L)
CSF glucose <½ blood glucose
CSF lymphocytosis
Lymph node TB
CT thorax with left anterior mediastinal nodes with necrotic centre
All samples should be sent for histocytopathological examination as well 
as culture and smear:
Fine needle aspiration or biopsy of an involved lymph node, usually under 
radiological guidance
Mediastinal nodal sampling (endobronchial ultrasound transbronchial 
needle aspiration, mediastinoscopy/mediastinotomy)
Box 28.42 Common sites of TB infection with radiological findings and diagnostic investigations
CSF, cerebrospinal fluid; MDT, multidisciplinary team meeting.', 1928),
   ('65af311e-083d-5728-a1f7-62d68eaec460', 'KUMAR_CLARK_10_2017', 'KC-C28', 971, 989, 0, '28
Respiratory Infection  971
Unwanted effects of drug treatment
The most common side-­effects of quadruple TB therapy are nau­
sea, vomiting, rash and itching. An antiemetic or antihistamine can 
be prescribed to alleviate these symptoms, although in some cases 
treatment may need to be interrupted. This is a particular problem 
when liver function tests become deranged and there is concern 
about a drug-­induced hepatitis, in which case it is often neces­
sary to stop all four drugs and re-­introduce one at a time. The drug 
should be stopped only if the serum bilirubin becomes elevated or if 
transferases are more than three times elevated.
Isoniazid can cause a polyneuropathy due to B6 deficiency, 
as isoniazid interacts with pyridoxal phosphate; vitamin B6, pyri­
doxine 10-25 mg daily, should be prescribed concomitantly to 
prevent this. Occasionally, isoniazid gives rise to allergic reac­
tions, such as a skin rash and fever. Hepatitis occurs in less than 
1% of cases but may lead to liver transplantation or death if the 
drug is continued.
Rifampicin induces liver enzymes, which may be transiently 
elevated in the serum of many patients. This also means that con­
comitant drug treatment may be made less effective and a careful 
review of a patient''s therapy will need to be undertaken, particularly 
with antidepressants, anticoagulants and antiepileptics (see p. 259). 
Oral contraception will not be effective, so alternative birth-­control 
methods should be used. Rifampicin stains body secretions red/
pink and patients should be warned of the change in colour of their 
urine, tears (affecting contact lenses) and sweat. Thrombocytopenia 
has been reported.
Pyrazinamide may cause hepatic toxicity but its most common 
side-­effects are itching, rash and arthralgia; pyrazinamide reduces 
the renal excretion of urate and may precipitate hyperuricaemic 
gout.
Ethambutol can cause a dose-­related optic retrobulbar neuritis 
that presents with colour blindness for green, reduction in visual 
acuity and a central scotoma. Patients should have their visual acu­
ity and colour vision checked prior to treatment using Snellen and 
Ishihara charts. This condition usually reverses, provided the drug 
is stopped when symptoms develop; patients should therefore be 
warned of its effects. All patients prescribed the drug should be 
seen by an ophthalmologist prior to treatment and doses of 15 mg/
kg should be used, with a maximum dose of 1.2 g. 
Drug resistance
Mono-­ or multidrug resistance arises due to incomplete or incorrect 
drug treatment (acquired) and can be spread from person to person. 
Isoniazid monoresistance occurs in approximately 10% of TB cases 
in the UK. A risk assessment for drug resistance should be routinely 
performed (Box 28.45). The incidence of multidrug resistance in 
TB (resistance to both rifampicin and isoniazid, termed MDR-­TB) is 
relatively low in developed countries (around 1%). Extremely drug-­
resistant disease (XDR-­TB) is defined as high-­level resistance to 
rifampicin, isoniazid, fluoroquinolones and at least one injectable 
agent such as amikacin, capreomycin or kanamycin. 
TB in special situations
Mycobacterium bovis infection
Mycobacterium bovis infection occurs in humans who have con­
sumed unpasteurized milk, farmers working with infected cows, and 
abattoir workers. TB due to M. bovis does not differ from ordinary 
TB in the chest but extrapulmonary sites of infection, such as lymph 
nodes, are more frequently involved. Immunosuppression is also a 
risk factor. The tuberculin test is positive. Treatment is with isoniazid, 
rifampicin and ethambutol; pyrazinamide resistance is common. 
HIV co-­infection
The increase in TB seen over recent decades has occurred to a 
considerable extent in association with the incidence of HIV infec­
tion, with high levels seen in Africa (particularly sub-­Saharan), the 
Indian subcontinent and parts of Eastern Europe and Russia. The 
incidence of HIV infection in TB worldwide is around 10% and TB 
is responsible for about one-­quarter of acquired immunodeficiency 
syndrome (AIDS)-­related deaths.
Alongside the increased morbidity and mortality of co-­infection, 
there are specific issues relating to the treatment of TB in HIV: 
namely, the incidence of drug interactions and intolerability, the 
increased risk of treatment toxicity and the higher incidence of 
drug resistance. TB/HIV infection should be managed by experts 
Site of disease
Duration of therapy
Drug choice
Pulmonarya
Extrapulmonary 
(excluding CNS 
disease)
Miliary (excluding 
CNS involve­
ment)
6 months
Fully sensitive strain: 
2HRZE + 4HRb
CNS TB
12 months
2HRZE + 10HR
Plus
Dexamethasone 
0.3-0.4 mg/kg per day 
weaned over 8-12 
weeks (or equivalent 
dose of prednisolone)
Latent TB
3 months
Or
6 months
3RH
Or
6H
Box 28.43 Usual treatment and duration in fully sensitive 
tuberculosis
 • Patients thought unlikely to comply:
 
- History of serious mental illness
 
- History of non-­adherence to TB or other therapies
 
- Previous TB treatment
 • Multidrug-­resistant TB
 • Street-­, shelter-­ or hostel-­dwelling homelessness; ''sofa surfing''
 • Prison history
 • Substance misuse (recreational drugs and alcohol)
Box 28.44 Criteria for implementation of directly observed 
therapy (DOT) for tuberculosis
 • History of prior drug treatment of TB (particularly if unsupervised and 
self-­administered)
 • Co-­infection with advanced HIV and previous TB treatment
 • Infection acquired in a region with high rates of drug resistance
 • Contact with a known case of resistant TB
 • Failure to respond to empirical TB therapy despite documented 
adherence
 • Exposure to multiple courses of fluoroquinolone antibiotics for presumed 
community-­acquired pneumonia
 • Healthcare workers exposed to cases of resistant TB
Box 28.45 Factors associated with an increased risk of 
drug-­resistant tuberculosis
aFor pulmonary TB, 2HRZE + 4(HR)3, i.e. 3 times weekly for 4HR, is acceptable.
b2HRZE + 4HR, 2 months of HRZE + 4 months of HR.
CNS, central nervous system; E, ethambutol; H, isoniazid; R, rifampicin; Z, pyrazinamide.', 6153),
   ('f5dbea5a-851c-56af-8275-cc64c7736529', 'KUMAR_CLARK_10_2017', 'KC-C28', 972, 990, 0, '28
972  Respiratory disease 
in TB (respiratory or infectious disease physicians) alongside HIV 
specialists. 
Latent TB infection
Latent TB infection (LTBI) is diagnosed by demonstrating immune 
memory to mycobacterial proteins. Two types of test are available.
In the tuberculin skin test (''Mantoux test'') a positive result 
is indicated by a delayed hypersensitivity reaction evident 48-72 
hours after the intradermal injection of purified protein deriva­
tive (PPD), resulting in a raised, indurated lesion. False-­negative 
(anergic) tuberculin skin tests (TSTs) are common in patients with 
immunosuppression due to HIV infection (CD4+ <200/mm3), those 
taking immunosuppressant medications (chemotherapy, anti-­TNF 
therapy, steroids), those at the extremes of age and those with 
active disease. False-­positives occur due to cross-­reactivity with 
non-­tuberculous mycobacteria and bacille Calmette-Guérin (BCG) 
vaccination.
Interferon-­gamma release assays (IGRAs) detect T-­cell secre­
tion of IFN-­γ following exposure to M. tuberculosis-­specific antigens 
(ESAT-­6, CFP-­10). Where a person has been previously infected or 
is currently infected with TB, activated T cells within their extracted 
whole blood secrete quantifiable levels of IFN-­γ in response to re-­
exposure to TB-­specific antigens. The test does not differentiate 
between active and latent infection. However, it is highly specific 
compared with the TST, has similar or better sensitivity, and requires 
only a single patient visit.
In certain groups with LTBI, chemoprophylaxis is offered to 
reduce the risk of active infection:
 • household and close workplace contacts of patients with pul­
monary and laryngeal TB
 • health workers
 • recent new migrant entrants from high-­risk countries
 • patients who are immunocompromised, such as those with HIV 
infection
 • those about to commence treatment with biologic agents (such 
as infliximab)
 • those due to have stem cell or solid organ transplants.
LTBI treatment is either with isoniazid and rifampicin for 3 
months or with isoniazid monotherapy for 6 months. 
BCG vaccination
BCG is a live attenuated vaccine derived from M. bovis that has 
lost its virulence. It has variable efficacy but is still recommended in 
certain situations in developed countries (but not the USA), though 
it is no longer offered routinely to all due to the lack of cost efficacy. 
In the UK it is still offered to all neonates in high-­risk areas such as 
inner cities, although there are safety concerns in babies with HIV. 
Non-­tuberculous mycobacterial infection
Non-­tuberculous mycobacteria (NTM) occur in soil and water, and are 
not usually pathogenic due to their lack of virulence. However, where 
there is a breach of the normal host defence mechanisms, certain 
strains have the potential to become pathogenic (Box 28.46). Factors 
associated with an increased risk of pulmonary NTM infection include 
structural lung disease such as COPD, bronchiectasis and cystic fibro­
sis, and immunosuppressive states such as HIV infection (see Box 
37.21). Treatment is suggested if there is a compatible clinical picture, 
the organism is isolated from an invasive sample or an NTM is isolated 
from more than one sputum sample obtained at different times.
Further reading
Conradie F, Diacon AH, Ngubane N et al. Treatment of highly drug -resistant 
pulmonary tuberculosis. N Engl J Med 2020; 382:893-902.
National Institute for Health and Care Excellence. NICE Clinical Guideline 
NG33: Tuberculosis. NICE 2016; https://www.nice.org.uk/guidance/ng33.
Tiberi S, du Plessis N, Walzl G et al. Tuberculosis: progress and advances in 
development of new drugs, treatment regimens, and host-­directed therapies. 
Lancet Infect Dis 2018; 18:e199-210.
Walzl G, McNerney R, Du Plessis N et al. Tuberculosis: advances and 
challenges in development of new diagnostics and biomarkers. Lancet Infect Dis 
2018; e183-198.
World Health Organization. Global Tuberculosis Report 2019; http://www.who.
int/. 
PLEURAL DISEASE
Pleural effusion
A pleural effusion is an excessive accumulation of fluid in the pleural 
space. It can be detected on X-­ray when 300 mL or more of fluid is 
present, and clinically when there is 500 mL or more. The chest X-­ray 
appearances (Fig. 28.31) range from obliteration of the costophrenic 
angle to dense homogeneous shadows occupying part or all of the 
hemithorax. Fluid below the lung (a subpulmonary effusion) can simu­
late a raised hemidiaphragm. Fluid in the fissures may resemble an 
intrapulmonary mass. The physical signs are are described in Box 28.8. 
Diagnosis
This is by pleural aspiration (see p. 944), usually done under ultra­
sound guidance. The fluid that accumulates may be a transudate or 
an exudate (Box 28.47).
Strain
Site of disease
M. avium intracel­
lulare complex 
(MAC)
Pulmonary (nodular and interstitial infiltrates 
in middle lobe in women or fibrocavitary 
disease in middle-­aged male smokers)
Disseminated (usually in HIV)
Hypersensitivity pulmonary disease (''hot-­tub 
lung'')
Lymphadenitis in children
M. kansasii
Pulmonary (similar presentation to Myco­
bacterium tuberculosis complex, usually 
in middle-­aged males)
Disseminated disease (in HIV)
M. abscessus
Skin, soft tissue and bone disease
Pulmonary (usually in bronchiectasis and 
older, non-­smoking females)
M. chelonae
Skin, bone and soft tissue
Pulmonary (similar to M. abscessus)
M. fortuitum
Pulmonary (similar to M. abscessus)
M. gordonae
Only rarely pathogenic (can be significant in 
immunocompromised host)
M. xenopi
Pulmonary (fibrocavitary disease in chronic 
obstructive pulmonary disease)
Contaminated surgical instruments causing 
bone/soft tissue infection
M. malmoense
Pulmonary
Lymph node
M. marinum
Soft tissue, skin and bone
M. szulgai
Pulmonary (similar to TB)
Box 28.46 Some non-­tuberculous mycobacteria strains 
implicated in disease', 5909),
   ('9ba255fe-f1aa-5d62-9c06-058304e2b816', 'KUMAR_CLARK_10_2017', 'KC-C28', 973, 991, 0, '28
Pleural Disease  973
Transudates
Effusions that are transudates can be bilateral but are often larger 
on the right side. The protein content is less than 30  g/L, the LDH 
is less than 200 IU/L and the fluid to serum LDH ratio is below 0.6. 
Causes include:
 • heart failure
 • hypoproteinaemia (e.g. nephrotic syndrome)
 • constrictive pericarditis
 • hypothyroidism
 • ovarian tumours producing right-­sided pleural effusion - Meigs'' 
syndrome. 
Exudates
The protein content of exudates is over 30  g/L and the LDH is more 
than 200 IU/L. Causes include:
 • bacterial pneumonia (common)
 • carcinoma of the bronchus - fluid may be blood-­stained (com­
mon)
 • pulmonary infarction
 • TB
 • autoimmune rheumatic diseases
 • post-­myocardial infarction syndrome (rare)
 • acute pancreatitis (high amylase content) (rare)
 • mesothelioma
 • sarcoidosis (very rare)
 • yellow-­nail syndrome (effusion due to lymphoedema) (very rare)
 • familial Mediterranean fever (very rare).
Pleural biopsy (see p. 944) may be necessary if the diagnosis 
has not been established by simple aspiration.
Management is of the underlying condition unless the fluid is 
purulent (empyema), in which case drainage is mandatory. 
Management of malignant pleural effusions
Malignant pleural effusions that reaccumulate and are symptom­
atic can be aspirated to dryness followed by the instillation of a 
sclerosing agent such as tetracycline or talc. Effusions should be 
drained slowly since rapid shift of the mediastinum causes severe 
pain and occasionally shock. This treatment produces only tem­
porary relief. 
Chylothorax
This is caused by accumulation of lymph in the pleural space, usu­
ally resulting from leakage from the thoracic duct following trauma 
or infiltration by carcinoma. 
Empyema
The presence of pus in the pleural space can be a complication of 
pneumonia. It requires urgent drainage (see p. 965). 
Pneumothorax
''Pneumothorax'' means air in the pleural space. Primary spon­
taneous pneumothoraces occur predominantly in young people. 
Traditionally, patients are tall, thin and male but shape, size and 
gender often do not follow this rule. Primary pneumothoraces are 
usually caused by rupture of a pleural bleb, usually apical, and 
are thought to be due to congenital defects in the connective 
tissue of the alveolar walls. Both lungs are affected with equal 
frequency.
Secondary pneumothoraces occur in conjunction with pre-­
existing lung disease such as COPD, infection and cystic fibrosis. 
Iatrogenic pneumothoraces are caused by instrumentation to the 
thorax, such as central venous line insertion, percutaneous or trans­
bronchial lung biopsy, or trauma. 
$
%
Fig. 28.31  Chest X-­ray demonstrating pleural effusion.  (A) Blunting of the left costophrenic angle 
due to a small left pleural effusion. There is a dual-­lead pacemaker in situ. (B) A large left-­sided pleural 
effusion.
 • Pleural fluid protein : serum protein >0.5
 • Pleural fluid LDH : serum LDH >0.6
 • Pleural fluid LDH > 2⁄3 upper limit of normal for serum (105-333 IU/L)
   
LDH, lactate dehydrogenase.
(Adapted from Light RW, Macgregor MI, Luchsinger PC et al. Pleural effusions: the di­
agnostic separation of transudates and exudates. Ann Intern Med 1972; 77:507-513.)
Box 28.47 Light''s criteria to diagnose an exudative effusion', 3344),
   ('d92f5412-0027-595b-9315-fad8a17e22fd', 'KUMAR_CLARK_10_2017', 'KC-C28', 974, 992, 0, '28
974  Respiratory disease 
Clinical features
Patients commonly present with sudden onset of chest drain and 
breathlessness. On careful questioning, they may be discovered 
to have had a milder version of these symptoms in the past but 
not sought medical attention. In tension pneumothorax they may 
become shocked, and emergency decompression of the pneumo­
thorax may be necessary using a 14-16 gauge needle in the second 
rib space in the mid-­clavicular line. 
Investigations
Plain chest X-­ray is the baseline investigation and the size of pneu­
mothorax should be recorded. There are several ways to measure: in 
North America the apex to cupola distance tends to be used, while 
UK guidelines recommend the pleura to edge of lung distance. If a 
patient''s first pneumothorax resolves and there is no recurrence, cross-­
sectional imaging with a CT chest is unnecessary. However, if the chest 
is abnormal on resolution, a scan should be requested. With the com­
mon use of cannabis and other recreational drugs, bullae and associ­
ated emphysema are being more commonly seen in young people. 
Management
Pneumothoraces can be managed in a number of ways (Fig. 28.32), 
depending on the cause and the severity of symptoms on presen­
tation. Treatment includes simple observation, pleural aspiration, 
intercostal drain and surgical management, both in the more acute 
situation or electively.
6PDOOSQHXPRWKRUD[
6PDOOULPRIDLU
%HVWVHHQRQ
H[SLUDWRU\;UD\
RI
UDGLRJUDSKLFYROXPH
0LQLPDOV\PSWRPV
1RUHFXUUHQFH
5HFXUUHQFH
$VSLUDWHDLU
5HPRYHWXEH
7DOFSOHXURGHVLV
6RPHUHFXUUHQFH
3OHXUHFWRP\
1RUHFXUUHQFH
,QVHUWLQWHUFRVWDOGUDLQDJH
WXEHZLWKXQGHUZDWHUVHDO
IRU±GD\V
5HVXPHQRUPDODFWLYLW\EXW
DYRLGVWUHQXRXVH[HUFLVH
2EVHUYHDWZHHNO\
LQWHUYDOVXQWLODLU
UHDEVRUEHG
5HH[SDQVLRQ
7XEHQRWEXEEOLQJ
3QHXPRWKRUD[UHPDLQV
7XEHEXEEOLQJ
6XUJHU\9$76
5H;UD\WRH[FOXGH
UHFXUUHQFH
0HGLXPSQHXPRWKRUD[
''HILQLWH±RI
UDGLRJUDSKLFYROXPH
/DUJHSQHXPRWKRUD[
2EYLRXV!RI
UDGLRJUDSKLFYROXPH
6RPHVKLIWRIWUDFKHD
DQGPHGLDVWLQXP
7HQVLRQSQHXPRWKRUD[
5HFXUUHQW
SQHXPRWKRUD[
5HFXUVPRUHWKDQWZLFH
LQUHFXULQILUVW\HDU
/XQJJURVVO\GHIODWHG
0DUNHGGHYLDWLRQRI
WUDFKHDDQG
PHGLDVWLQXP
Fig. 28.32  Pneumothorax: an algorithm for management.  Red: pneumothorax. VATS, video-­
assisted thoracoscopic surgery.', 2336),
   ('3267d76e-3b15-51d1-ab2a-6698b165c0e7', 'KUMAR_CLARK_10_2017', 'KC-C28', 975, 993, 0, '28
Tumours of the Respiratory Tract  975
 • Observation: For patients with mild symptoms and a pneumotho­
rax of <2 cm simple observation is enough. Patients can be dis­
charged from the emergency department with instructions to return 
if their symptoms become worse. They should be advised not to fly 
until the pneumothorax has completely resolved and never to scuba 
dive unless they have had surgical pleurodesis (Box 28.48). They 
have a 30% chance of a recurrent pneumothorax. Patients often 
ask about sport and exercise, and while there are no real restrictions, 
apart from diving, they should generally rest for a few days before 
exercising in moderation and should avoid contact sports for a week 
or two. Outpatient follow-­up should be arranged within 10 days.
 • Aspiration: This can be considered in symptomatic patients with 
a pneumothorax of >2 cm, or 1 cm in a secondary pneumotho­
rax. It is undertaken using a 16 French gauge needle attached 
to a three-­way tap and a 50 mL syringe (Box 28.49). Generally, 
aspiration should not be attempted in most cases of traumatic 
pneumothorax. It should be followed by a repeat chest X-­ray, 
discharge advice (as described) and outpatient follow-­up.
 • Pleural intercostal drain: If aspiration fails to inflate the lung sat­
isfactorily, the patient is very breathless on admission, there is evi­
dence of a tension pneumothorax or the cause is related to trauma, 
an intercostal drain should be inserted, normally in the mid-­axillary 
line 4th intercostal space. The tube should be connected to an un­
derwater drain and bottle, which are kept below the level of the 
patient''s chest. It should be checked daily for evidence of infection 
at the insertion site and for kinks and leaks along its course.
 • Surgical pleurodesis and bleb resection: An open surgical pleu­
rodesis via thoracotomy or VATS procedure should be considered 
when the lung fails to re-­inflate, or offered to patients electively.
 • Smoking: Patients should be strongly advised to stop smok­
ing both tobacco and recreational drugs. Cannabis, in particular, 
can cause marked emphysematous changes in younger people, 
which leads to subcutaneous blebs and bullae.
 • Psychological effects: Medical staff underestimate the concern 
that patients often feel, knowing that they have a medical condi­
tion that can potentially recur at any time. Some become very 
anxious and often request surgical pleurodesis after their second 
or third recurrence.
Further reading
British Thoracic Society. Investigation of a unilateral pleural effusion in adults: 
British Thoracic Society pleural disease guideline 2010. Thorax 2010; 65(Suppl 
2):ii4-ii17.
British Thoracic Society. Management of spontaneous pneumothorax: British 
Thoracic Society pleural disease guideline 2010. Thorax 2010; 65(Suppl 2):ii18-
ii31.
Courtney Broaddus V. Clearing the air - a conservative option for spontaneous 
pneumothorax. N Engl J Med 2020; 382:469-470. 
TUMOURS OF THE RESPIRATORY 
TRACT
Malignant tumours
Bronchial carcinoma
Bronchial carcinoma is the most common malignant tumour world­
wide, causing around 1.76 million deaths annually. It is the fifth most 
frequent cause of death in the UK and is now the most common 
cause of cancer-­related death in both men and women.
Cigarette smoking (including passive smoke exposure) accounts 
for 80% and 90% of lung cancer in men and women, respectively. 
There remains a higher incidence of bronchial carcinoma in urban 
compared with rural areas, even when allowance is made for ciga­
rette smoking. Other aetiological factors include:
 • Environmental: radon exposure, asbestos, polycyclic aromatic 
hydrocarbons and ionizing radiation; occupational exposure to 
arsenic, chromium, nickel, petroleum products and oils.
 • Host factors: pre-­existing lung disease such as pulmonary fi­
brosis; HIV infection; genetic factors.
Legislative control over smoking in public places in many parts 
of the world has been introduced to reduce ill health related to ciga­
rette smoke. 
Pathophysiology
Historically, lung cancers have been broadly divided into small-­cell 
carcinoma and non-­small-­cell carcinoma, based on the histological 
appearances of the cells seen within the tumour. This distinction is 
necessary with respect to the behaviour of the tumour, providing prog­
nostic information and determining best treatment. Non-­small-­cell 
carcinoma is further divided into a number of cell types (adenocarci­
noma, squamous cell carcinoma, large-­cell carcinoma (Box 28.50). A 
number of molecular characteristics have been described in the sub­
types of cancer, which confer potential prognostic benefit and may 
result in the ability to deliver a more personalized therapy with targeted 
agents. The most common of these are activating mutations within epi­
dermal growth factor receptor (EGFR), most commonly encountered 
in non-­smokers, females and those of Asian origin, and the presence 
of anaplastic lymphoma kinase (ALK) fusion oncogene, again more 
commonly found in non-­smokers or ex-­smokers and younger patients 
(see p. 119). 
Clinical features
The presentation and clinical course vary between the different 
cell types (see Box 28.50). Symptoms and signs may be different, 
depending on the extent and site of disease.
Common presenting features can be divided into those caused 
by direct/local tumour effects, metastatic spread and non-­metastatic 
extrapulmonary features.
Local effects
 • Cough. This is the most commonly encountered symptom in 
lung cancer. Because evidence suggests that this symptom is 
neglected by both patients and healthcare professionals, cam­
paigns in the UK have highlighted the ''3-­week cough'' as a 
symptom that merits a chest X-­ray.
 • No flying for 1 week after complete resolution
 • No diving
 • Smoking cessation
 • 30-50% chance of recurrence
 • Future management: consider surgery
Box 28.48 Advice to patients after pneumothorax
 1. Explain the nature of the procedure and obtain consent.
 2. Infiltrate 2% lidocaine down to the pleura in the second intercostal space 
in the mid-­clavicular line.
 3. Push a 3-4 cm 16-­gauge cannula through the pleura.
 4. Connect the cannula to a three-­way tap and 50 mL syringe.
 5. Aspirate up to 2.5 L of air. Stop if resistance to suction is felt or the 
patient coughs excessively.
 6. Repeat the chest X-­ray (in expiration) in the X-­ray department.
Box 28.49 Simple aspiration of pneumothorax', 6491),
   ('8b932f2e-38e2-5217-a87e-3683c6f8b106', 'KUMAR_CLARK_10_2017', 'KC-C28', 976, 994, 0, '28
976  Respiratory disease 
 • Breathlessness. Central tumours occlude large airways, result­
ing in lung collapse and breathlessness on exertion. Many pa­
tients with lung cancer have coexistent COPD, which is also a 
cause of breathlessness. Patients may also develop a pleural 
effusion due to metastatic involvement of the pleura.
 • Haemoptysis. Fresh or old blood is coughed up because of the 
tumour bleeding into an airway.
 • Chest pain. Peripheral tumours invade the chest wall or pleura 
(both well innervated), resulting in sharp pleuritic pain. Large-­
volume mediastinal nodal disease often results in a characteris­
tic dull central chest ache.
 • Wheeze. This is monophonic when due to partial obstruction of 
an airway by tumour.
 • Hoarse voice. Mediastinal nodal or direct tumour invasion of the 
mediastinum results in compression of the left recurrent laryn­
geal nerve.
 • Nerve compression. Pancoast tumours in the apex of the lung 
invade the brachial plexus, causing C8/T1 palsy with small mus­
cle wasting in the hand and weakness, as well as pain, radiating 
down the arm. An associated Horner''s syndrome also occurs, 
caused by compression of the sympathetic chain, with classic 
features of miosis, ptosis and anhidrosis.
 • Recurrent infections. Tumour causing partial obstruction of an 
airway results in post-­obstructive pneumonia.
 • Direct invasion of the phrenic nerve. Bronchial carcinoma 
invading the phrenic nerve causes paralysis of the ipsilateral 
hemidiaphragm. It can involve the oesophagus, producing pro­
gressive dysphagia, and the pericardium, resulting in pericardial 
effusion and malignant dysrhythmias.
 • Superior vena caval obstruction. See page 117.
 • Tracheal tumours. These present with progressive dyspnoea 
and stridor. Flow-volume curves show dramatic reductions in 
inspiratory flow (see Fig. 28.6C). 
Metastatic spread
Bronchial carcinoma commonly spreads to mediastinal, cervical and 
even axillary or intra-­abdominal nodes. In addition, the liver, adrenal 
glands, bones, brain and skin are frequent sites for metastases:
 • Liver. Common symptoms are anorexia, nausea and weight 
loss. Right upper quadrant pain radiating across the abdomen 
is associated with liver capsular pain.
 • Bone. Bony pain and pathological fractures occur as a result of 
tumour spread. If the spine is involved, there is a risk of spinal 
cord compression (see p. 878), which requires urgent treatment.
 • Adrenal glands. Metastases to the adrenals do not usually re­
sult in adrenal insufficiency and are generally asymptomatic.
 • Brain. Metastases present as space-­occupying lesions with 
subsequent mass effect and signs of raised intracranial pres­
sure. Less common presentations include carcinomatous men­
ingitis with cranial nerve defects, headache and confusion.
 • Malignant pleural effusion. This presents with breathlessness 
and is commonly associated with pleuritic pain. 
Non-­metastatic extrapulmonary manifestations of 
bronchial carcinoma
discussed later Minor haematological extrapulmonary manifesta­
tions of lung cancer, such as normocytic anaemia and thrombo­
cytosis, are reasonably common. Apart from finger clubbing and 
hypertrophic pulmonary osteoarthropathy (HPOA), most other non-­
metastatic complications are relatively rare. Approximately 10% of 
small-­cell tumours produce ectopic hormones, giving rise to para­
neoplastic syndromes (see Box 6.9). 
Investigations
Investigations are necessary to:
 • stage the extent of disease
 • make a tissue diagnosis (to differentiate small-­cell from non-­
small-­cell lung cancer, as well as to detail the molecular char­
acteristics - increasingly relevant with newer targeted biologic 
agents and immunotherapy)
 • assess fitness to undergo treatment.
Staging and diagnosis
Chest X-­ray
Plain chest X-­rays may show obvious evidence of lung cancer or 
non-­specific appearances (Box 28.51). In some cases the initial film 
is normal, either because the lesion is small or because disease is 
confined to central structures. 
Computed tomography
CT indicates the extent of disease. Imaging should include the liver 
and adrenal glands, which are common sites for metastases. The 
Cell type
Incidence 
in UK (%)
Features
Non-­small-­cell 
carcinoma
Squamous cell 
carcinoma
35
Remains the most common cell type 
in Europe
Arises from epithelial cells, associated 
with production of keratin
Occasionally cavitates with central 
necrosis
Causes obstructing lesions of bron­
chus with post-­obstructive infection
Local spread common, metastasizes 
relatively late
Adenocarcinoma
27-30
Likely to become the most common 
cell type in the UK in the near 
future (most common cell type in 
the USA)
Increasing incidence since 2005 pos­
sibly linked to low-­tar cigarettes
Originates from mucus-­secreting 
glandular cells
Most common cell type in 
­non-­smokers
Often causes peripheral lesions on 
chest X-­ray/CT
Subtypes include bronchoalveolar cell 
carcinoma (associated with copious 
mucus secretion, multifocal disease)
Metastases common: pleura, lymph 
nodes, brain, bones, adrenal glands
Large-cell 
carcinoma
10-15
Often poorly differentiated
Metastasizes relatively early
Small-­cell 
carcinoma
20
Arises from neuroendocrine cells 
(APUD cells)
Often secretes polypeptide hormones
Often arises centrally and 
metastasizes early
Box 28.50 Lung cancer cell types and clinical features', 5429),
   ('612089c5-6e42-59c9-af2f-ec6718a56e94', 'KUMAR_CLARK_10_2017', 'KC-C28', 977, 995, 0, '28
Tumours of the Respiratory Tract  977
Mass lesion
Lesions visible if >1 cm in diameter. Spiculated, 
cavitating or smooth-­edged. Often an incidental 
finding, usually asymptomatic if small. By the 
time symptoms are present, chest X-­ray is 
almost always abnormal
Pleural effusion
Usually unilateral; can obscure an underlying 
mass or pleural tumour. Mesothelioma and meta­
static disease from other tumour sites are in the 
differential diagnosis
Mediastinal widening or hilar adenopathy
Lymphadenopathy evident on the plain film, 
manifested by splayed carina, hilar enlargement 
or paratracheal shadowing
Slow-­resolving consolidation
Tumour causes partial obstruction of a 
bronchus, resulting in retention of secretions, 
bacterial overgrowth and subsequent infection. 
(Persistent right upper lobe consolidation due 
to tumour in right upper lobe)
Collapse
Endoluminal tumour causes complete collapse 
of a lung and associated mediastinal shift, 
or collapse of a lobe or segment, resulting in 
volume loss on the affected side with raised 
hemidiaphragm/deviated trachea
Reticular shadowing
Carcinoma spreads through the lymphatic 
channels of the lung to give rise to lymphangitis 
carcinomatosa; in bronchial carcinoma this is 
usually unilateral and associated with striking 
dyspnoea. Bilateral lymphangitis should prompt 
investigation for a primary site other than lung, 
such as breast, stomach or colon
Normal
A normal film does not rule out an underlying tumour. A minority of tumours are confined to the central 
airways and mediastinum without obvious change on plain chest X-­ray. Although investigation of 
isolated haemoptysis with a normal chest X-­ray is often negative, a normal chest X-­ray should not 
discourage further investigation, especially in smokers over the age of 40 years
Box 28.51 Lung cancer presentations on chest X-­ray', 1867),
   ('5836a814-a51d-5631-8a9a-1b23838a4ac6', 'KUMAR_CLARK_10_2017', 'KC-C28', 978, 996, 0, '28
978  Respiratory disease 
International Association for the Study of Lung Cancer (IASLC) has 
devised the most widely used staging definitions, based on CT 
imaging of tumour size (T), nodal involvement (N) and metastases 
(M), along with prognostic data (Box 28.53).
Using CT criteria, lymph nodes that are less than 1 cm in diam­
eter are not classed as being enlarged, yet they can still contain 
malignant cells. With increasing size, the positive predictive value 
of CT in detecting malignant nodes grows; however, it cannot be 
assumed that enlarged nodes are definitely malignant and further 
staging tests should be performed if there are no distant metas­
tases, and the primary tumour is thought to be eligible for curative 
treatment. These tests include direct sampling of affected nodes 
and PET-­CT to assess distant spread of cancer.
If cerebral metastases are suspected, CT imaging of the brain 
should be performed. 
PET-­CT
See page 941. 
Other imaging modalities
MRI is not useful for the diagnosis of primary lung tumours other 
than Pancoast tumours with nerve invasion or the assessment of 
chest wall involvement prior to surgery. MRI spine is required if there 
is any clinical suspicion of spinal cord compression. MRI brain may 
also be required to assess cerebral metastases.
Bone is a common site for metastatic deposits, and CT imag­
ing of the primary tumour may demonstrate bony metastases. If 
the patient is describing bony pain that is not included in the CT 
imaging field, a bone scan may be helpful to demonstrate bony 
deposits. If these are identified, local radiotherapy may be helpful in 
controlling local symptoms such as pain. 
Obtaining histology and cytology
Investigations for this purpose are listed in Box 28.54. 
Other investigations
These include a full blood count for the detection of anaemia, and 
biochemistry to assess for liver involvement, hypercalcaemia and 
hyponatraemia. Investigations for non-metastatic extrapulmonary 
manifestations of cancer may be indicated (Box 28.52) 
Assessing fitness for treatment
The Eastern Cooperative Oncology Group (ECOG) performance sta­
tus should be recorded for all patients with suspected malignancy 
(Box 28.55). Before radical treatment, an assessment of fitness for 
treatment should be carried out. This work-­up should include full 
lung function testing with transfer capacity, and if cardiovascular 
disease is present, cardiopulmonary exercise testing, stress echo 
or, occasionally, preoperative angiography may be required. 
Management
Treatment of lung cancer (see also p. 119) involves several different 
modalities and should be planned by a multidisciplinary team. In the 
UK, approximately 75% of patients will have advanced lung cancer 
at the stage of presentation: hence radical treatment is not an option. 
Patient co-­morbidities may also preclude radical treatment. Box 
28.56 shows the mean survival based on tumour stage for non-­small-­
cell lung cancer (NSCLC), including squamous cell carcinoma: only 
25-30% of patients are still alive 1 year after diagnosis and only 6-8% 
after 5 years. Small-­cell carcinoma is staged as limited or extensive 
disease. The treatment and prognosis differ from those of NSCLC.
Surgery
Surgery is performed in early-­stage NSCLC (stages I, II and selected 
IIIA) with curative intent. Many patients with stage III disease are 
treated with chemoradiation with a view to downstaging disease 
and rendering it amenable to surgical resection. Where surgical 
staging of resected lung cancer demonstrates nodal involvement, 
patients require adjuvant chemotherapy. 
Radiation therapy with curative intent
In selected patients with adequate lung function and early-­stage 
NSCLC, high-­dose radiotherapy or continuous hyperfractionated 
accelerated regimens (CHART) provide a good alternative to surgi­
cal resection with almost comparable outcomes. It is the treatment 
of choice if surgery is not possible due to co-­morbidities. Radiation 
pneumonitis (defined as an acute infiltrate precisely confined to the 
radiation area and occurring within 3 months of radiotherapy) devel­
ops in 10-15% of cases. Radiation fibrosis, a fibrotic change occur­
ring within a year or so of radiotherapy and not precisely confined to 
the radiation area, occurs to some degree in all cases.
In patients with significant cardiovascular or respiratory co-­
morbidities and early stage I disease, stereotactic ablative radiother­
apy (SABR) can be used. In the same patient group, radiofrequency 
ablation is used: this is an image-­guided technique that uses heat 
to destroy small peripheral tumours. Data regarding long-­term out­
comes are unavailable as yet. 
Palliative radiation treatment
Radiation therapy has a role in palliation of symptoms from lung can­
cer. Bone and chest wall pain from metastases or direct invasion, 
haemoptysis, occluded bronchi and superior vena caval obstruction 
Metabolic (universal at some stage)
 • Loss of weight
 • Lassitude
 • Anorexia 
Endocrine (10%) (usually small-­cell carcinoma)
 • Ectopic adrenocorticotrophin syndrome
 • Syndrome of inappropriate secretion of antidiuretic hormone (SIADH)
 • Hypercalcaemia (usually squamous cell carcinoma)
 • Rarer: hypoglycaemia, thyrotoxicosis, gynaecomastia 
Neurological (2-16%)
 • Encephalopathies - including subacute cerebellar degeneration
 • Myelopathies - motor neurone disease
 • Neuropathies - peripheral sensorimotor neuropathy
 • Muscular disorders - polymyopathy, myasthenic syndrome (Eaton-
Lambert syndrome) 
Vascular and haematological (rare)
 • Thrombophlebitis migrans
 • Non-­bacterial thrombotic endocarditis
 • Microcytic and normocytic anaemia
 • Disseminated intravascular coagulopathy
 • Thrombotic thrombocytopenic purpura
 • Haemolytic anaemia 
Skeletal
 • Clubbing (30%)
 • Hypertrophic osteoarthropathy (± gynaecomastia) (3%) 
Cutaneous (rare)
 • Dermatomyositis
 • Acanthosis nigricans
 • Herpes zoster
   
Percentage of all cases.
Box 28.52 Non-­metastatic extrapulmonary manifestations of 
bronchial carcinomaa', 6096),
   ('cbff55f5-9b50-5a6c-afd3-662a574af19a', 'KUMAR_CLARK_10_2017', 'KC-C28', 979, 997, 0, '28
Tumours of the Respiratory Tract  979
Notation
Description
T - primary tumour
TX
Primary tumour cannot be assessed, or tumour proven by the presence of malignant cells in sputum or bronchial washings, but not 
visualized by imaging or bronchoscopy
T0
No evidence of primary tumour
Tis
Carcinoma in situa
T1
Tumour 3 cm or less in greatest dimension, surrounded by lung or visceral pleura, without bronchoscopic evidence of invasion more 
proximal than the lobar bronchus (i.e. not in the main bronchus); subtypes mi, a, b and c exist according to the tumour size.
T2
Tumour more than 3 cm but not more than 5 cm; or tumour with any of the following features:b
 • Involves main bronchus, regardless of distance to the carina but without involvement of the carina
 • Invades visceral pleura
 • Associated with atelectasis or obstructive pneumonitis that extends to the hilar region involving either part of or the entire lung
  T2a
Tumour more than 3 cm but not more than 4 cm in greatest dimension
  T2b
Tumour more than 4 cm but not more than 5 cm in greatest dimension
T3
Tumour more than 5 cm but not more than 7 cm in greatest dimension or one that directly invades any of the following: parietal pleura, 
chest wall (including superior sulcus tumours), phrenic nerve, parietal pericardium; or tumour nodule(s) in the same lobe as the primary
T4
Tumour more than 7 cm or of any size that invades any of the following: diaphragm, mediastinum, heart, great vessels, trachea, 
recurrent laryngeal nerve, oesophagus, vertebral body, carina; separate tumour nodule(s) in a different ipsilateral lobe to the primary
N - regional lymph nodes
NX
Regional lymph nodes cannot be assessed
N0
No regional lymph node metastasis
N1
Metastasis in ipsilateral peribronchial and/or ipsilateral hilar lymph nodes and intrapulmonary nodes, including involvement by direct 
extension
N2
Metastasis in ipsilateral mediastinal and/or subcarinal lymph node(s)
N3
Metastasis in contralateral mediastinal, contralateral hilar, ipsilateral or contralateral scalene, or supraclavicular lymph node(s)
M - distant metastasis
M0
No distant metastasis
M1
Distant metastasis
  M1a
Separate tumour nodule(s) in a contralateral lobe; tumour with pleural nodules or malignant pleural or pericardial effusionc
  M1b
Single extrathoracic metastasis in a single organd
  M1c
Multiple extrathoracic metastasis in a single or multiple organs
Resultant stage groupings
Occult carcinoma
TX
N0
M0
Stage 0
Tis
N0
M0
Stage IAe
T1
N0
M0
Stage IB
T2a
N0
M0
Stage IIA
T2b
N0
M0
Stage IIB
T1, T2a, b
N1
M0
T3
N0
M0
Stage IIIA
T1, T2a, b
N2
M0
T3
N1
M0
T4
N0, N1
M0
Stage IIIB
T1, T2a, b
N3
M0
T3, T4
N2
M0
Stage IIIC
T3, T4
N3
M0
Stage IV
Any T
Any N
M1
Stage IVA
Any T
Any N
M1a, M1b
Stage IVB
Any T
Any N
M1c
aTis includes adenocarcinoma in situ and squamous carcinoma in situ.
bT2 tumours with these features are classified T2a if 4 cm or less or if size cannot be determined, and T2b if greater than 4 cm but not larger than 5 cm.
cMost pleural (pericardial) effusions with lung cancer are due to tumour. In a few patients, however, multiple microscopic examinations of pleural (pericardial) fluid are negative for tumour, and the fluid is 
non-­bloody and is not an exudate. Where these elements and clinical judgement dictate that the effusion is not related to the tumour, the effusion should be excluded as a staging descriptor.
dThis excludes involvement of a single non-­regional node.
eStage IA is split into three subclasses 1, 2 and 3 according to tumour size.
(Based on data from Goldstraw P, Crowley J, Chansky K et al.; International Association for the Study of Lung Cancer International Staging Committee; Participating Institutions. The IASLC Lung 
Cancer Staging Project: proposals for the revision of the TNM stage groupings in the forthcoming (8th) edition of the TNM classification of malignant tumours. J Thorac Oncol 2016; 2:706-714.)
Box 28.53 TNM staging system for lung cancer', 3965),
   ('0f1c967c-e0ef-52d0-96d2-668555e35069', 'KUMAR_CLARK_10_2017', 'KC-C28', 980, 998, 0, '28
980  Respiratory disease 
respond favourably to irradiation in the short term. Radiotherapy is 
also given at the end of chemotherapy to consolidate treatment in 
small-­cell lung cancer. 
Chemotherapy, targeted therapy and 
immunotherapy
This is discussed on page 119-120. Adjuvant chemotherapy with 
radiotherapy improves response rate and extends median survival 
in NSCLC.
Targeted agents against EGFRs, tyrosine kinases and anaplastic 
lymphoma kinase (ALK) in NSCLC (in particular, adenocarcinoma) 
offer better outcomes in selected patients and can also be used 
where intravenous chemotherapy offers unacceptable toxicity or as 
second-­line chemotherapy. Immunotherapy with checkpoint inhibi­
tors and PDL-1 inhibitors modulates the immune response and 
offers another treatment option in appropriate patient groups. This 
is an emerging field and may have an impact on the prognosis of all 
types of lung cancer. 
Laser therapy, cryotherapy and tracheobronchial 
stents
These techniques are used in the palliation of inoperable lung 
cancer in selected patients with tracheobronchial narrowing from 
intraluminal tumour, or extrinsic compression causing disabling 
breathlessness, intractable cough and complications including 
infection, haemoptysis and respiratory failure.
A neodymium-­Yag (Nd-­Yag) laser passed through a fibreoptic 
bronchoscope can be used to vaporize inoperable fungating intralu­
minal carcinoma involving short segments of trachea or main bron­
chus. Benign tumours, strictures and vascular lesions can also be 
treated effectively with immediate relief of symptoms.
Cryotherapy is an endobronchial technique by which a cryo­
probe is passed through the bronchoscope. The cryoprobe 
repeatedly freezes and thaws the tumour, which enables parts of it 
to be excised, restoring airway patency without causing bleeding. 
The excised tissue can be sent for histological analysis.
Tracheobronchial stents made of silicone or in the form of 
expandable metal springs are available for insertion into strictures 
caused by tumour, external compression, or weakening and col­
lapse of the tracheobronchial wall. 
Palliative care
Patients dying of cancer of the lung need attention to their overall 
wellbeing (see Ch. 7). Much can be done to render the individu­
al''s remaining life symptom-­free and as active as possible. Patient 
and relatives both require psychological and emotional support, a 
task that should be shared between the respiratory team, oncology 
team, primary care team and nurses, social workers, hospital chap­
lains and doctors who together make up the palliative care team. 
Mesothelioma
Mesothelioma describes a malignant tumour arising from the pari­
etal or visceral mesothelial lining of the lung. These tumours are 
almost always related to asbestos exposure (see p. 996), and 
mesothelioma typically develops from pre-­existing pleural plaque 
disease.
The number of cases of mesothelioma has increased progressively 
since the mid-­1980s and has now reached 2500 deaths per year in the 
UK, which has the highest per capita death rate from this condition.
The most common presentation of mesothelioma is a pleural 
effusion, typically with persistent chest wall pain, which should 
raise the index of suspicion even if the initial pleural fluid or biopsy 
samples are non-­diagnostic. CT/ultrasound-­guided biopsy or VATS 
pleural biopsy is often needed to obtain sufficient tissue for diag­
nosis. Clinical trials of chemotherapy, sometimes combined with 
surgery, are under way but the outlook for most patients remains 
very limited. 
Secondary tumours
Metastases in the lung are very common. They are usually detected 
on chest X-­ray or CT in patients already diagnosed as having 
 • Fibreoptic bronchoscopy (Fig. 28.33)
 • Endobronchial ultrasound (Fig. 28.34)
 • CT/ultrasound-­guided biopsy of lung lesions
 • Ultrasound-­guided biopsy of lymph nodes, liver metastases or skin 
­lesions
 • Ultrasound-­guided pleural aspiration
 • Medical or video-­assisted thoracoscopy
 • Mediastinoscopy
Box 28.54 Investigations to obtain histology and cytology
Grade
Description
0
Fully active, able to carry out all pre-­disease 
­performance without restriction
1
Restricted in physically strenuous activity but 
ambulatory and able to carry out work of a light or 
sedentary nature, e.g. light house work, office work
2
Ambulatory and capable of all self-­care but unable to 
carry out any work activities. Up and about more than 
50% of waking hours
3
Capable of only limited self-­care. Confined to bed or 
chair for more than 50% of waking hours
4
Completely disabled; cannot carry out any self-­care; 
totally confined to bed or chair
5
Dead
Box 28.55 Eastern Cooperative Oncology Group (ECOG) 
Performance Status
Stagea
5-­year survival (%)
IA1
92
IA2
83
IA3
77
IB
68
IIA
60
IIB
53
IIIA
36
IIIB
26
IIIC
13
IVA
10
IVB
0
Box 28.56 Survival in small-­cell and non-­small-­cell cancer 
based on clinical stagea
aSee Box 28.53.
(Based on data from Goldstraw P, Crowley J, Chansky K et al.; International Association for 
the Study of Lung Cancer International Staging Committee; Participating Institutions. The 
IASLC Lung Cancer Staging Project: proposals for the revision of the TNM stage groupings 
in the forthcoming (8th) edition of the TNM classification of malignant tumours. J Thorac 
Oncol 2016; 2:706-714.)', 5387),
   ('ac554de5-d762-5e89-8d8b-b4f06ad70a31', 'KUMAR_CLARK_10_2017', 'KC-C28', 981, 999, 0, '28
Tumours of the Respiratory Tract  981
carcinoma but can be the first presentation. Typical sites for the 
primary tumour include the kidney, prostate, breast, bone, gastroin­
testinal tract, cervix or ovary.
Carcinoma, particularly of the stomach, pancreas and breast, 
can involve mediastinal glands and spread along the lymphatics 
of both lungs, leading to progressive and severe breathlessness 
(lymphangitis carcinomatosis). On the chest X-­ray, bilateral lymph­
adenopathy is seen, together with streaky basal shadowing fanning 
out over both lung fields.
Single pulmonary metastases can be removed surgically but, 
as CT scans usually show the presence of small metastases unde­
tected on chest X-­ray, detailed imaging, including PET scanning 
and assessment, is essential before undertaking surgery. 
Solitary pulmonary nodules
A solitary pulmonary nodule is defined as a discrete lesion of less 
than 3 cm in diameter. The differential diagnoses for a solitary pul­
monary nodule are:
 • primary bronchial carcinoma
 • pulmonary metastases
 • inflammatory lesions, e.g. rounded pneumonia or abscess
 • granuloma
 • benign tumour of the lung, e.g. hamartoma
 • rheumatoid nodules
 • hydatid cyst.
With the increased use of CT scanning for other conditions, 
there has been greater incidental detection of asymptomatic, small, 
sub-­centimetre nodules. The majority of these are benign; however, 
radiological follow-­up should be arranged at intervals in line with 
recommended guidelines, determined by the size of the nodule in 
millimetres and the risk of developing malignancy. Scoring tools 
such as the Brock score are useful in assessing the risk of malig­
nancy based on nodule characteristics and size. 
Screening for lung cancer
A large trial carried out in the USA has demonstrated a 20% mor­
tality benefit from low-­dose helical CT screening for lung cancer in 
high-­risk populations of smokers and ex-­smokers between the ages 
of 55 and 74. A similar trial has been undertaken in the Netherlands 
and the UK. It is likely that low-­dose CT screening will be employed 
in the future to detect cancer at an earlier stage so that curative 
treatment may be offered. 
$RUWD
2HVRSKDJXV



E
E




















D
6XSUDFODYLFXODU]RQH

/RZFHUYLFDOVXSUDFODYLFXODU

DQGVWHUQDOQRWFKQRGHV
8SSHU]RQH²VXSHULRU
PHGLDVWLQDOQRGHV

8SSHUSDUDWUDFKHDO
D 3UHYDVFXODU
E 5HWURWUDFKHDO

/RZHUSDUDWUDFKHDO
6XEFDULQDODQGORZHU]RQHV²
LQIHULRUPHGLDVWLQDOQRGHV
6XEFDULQDO]RQH

6XEFDULQDO
/RZHU]RQH

3DUDRHVRSKDJHDO

EHORZFDULQD

3XOPRQDU\OLJDPHQW
1QRGHV
+LODULQWHUOREXODU]RQH
 +LODU
 ,QWHUOREDU
3HULSKHUDO]RQH
 /REDU
 6HJPHQWDO
 6XEVHJPHQWDO
$QWHURSRVWHULRU]RQH²
DRUWLFQRGHVQRWVKRZQ

6XEDRUWLF

3DUDDRUWLF
Fig. 28.34  Lymph node stations commonly involved in lung cancer.  These nodes are sampled dur­
ing staging investigations.
Fig. 28.33  Bronchoscopic view of a bronchial carcinoma ob­
structing a large bronchus.', 3044),
   ('7922b4d2-4c9c-528b-aee2-fa3ff8ed049b', 'KUMAR_CLARK_10_2017', 'KC-C28', 982, 1000, 0, '28
982  Respiratory disease 
Bronchial carcinoid tumours
These rare tumours are typically slow-­growing, low-­grade malignant 
neoplasms. They arise from neuroendocrine tumours and account 
for approximately 1% of all bronchial tumours. Many of these may 
be asymptomatic. Some patients will present with symptoms related 
to obstruction, recurrent infection or haemoptysis. The histological 
appearance may range from low-­grade typical tumours to atypi­
cal tumours. Surgery is usually the treatment of choice, although 
patients will require long-­term surveillance. As foregut deriva­
tives, bronchial carcinoids produce adrenocorticotrophic hormone 
(ACTH) but do not usually produce the 5-­hydroxytryptamine that is 
seen in midgut or hindgut carcinoid tumours. Staging of carcinoid 
tumours is the same as for NSCLC. 
Benign tumours
Pulmonary hamartoma
This is the most common benign tumour of the lung and is usually 
seen on X-­ray as a very well-­defined round lesion 1-2 cm in diam­
eter in the periphery of the lung. Growth is extremely slow but the 
tumour can reach several centimetres in diameter. Rarely, it arises 
from a major bronchus and causes obstruction. 
Bronchial adenoma
This diverse group of benign tumours arises from mucus glands and 
ducts of the windpipe. 
Cylindroma, chondroma and lipoma
These extremely rare tumours grow in the bronchus or trachea, 
causing obstruction. 
Tracheal tumours
Benign tumours include squamous papilloma, leiomyoma and 
haemangiomas.
Further reading
Callister MEJ, Baldwin DR, Akram AR; British Thoracic Society. BTS 
guidelines for the investigation and management of pulmonary nodules. Thorax 
2015; 70:suppl 2.
Field JK, Duffy SW, Baldwin DR et al. UK Lung Cancer RCT Pilot Screening 
Trial: baseline findings from the screening arm provide evidence for the potential 
implementation of lung cancer screening. Thorax 71:161-170.
International Association for the Study of Lung Cancer. 8th Edition of the 
TNM Classification for Lung Cancer. IASLC 2017; www.iaslc.org.
National Institute for Health and Care Excellence. NICE Guideline 122: Lung 
Cancer: Diagnosis and Management. NICE 2019; http://www.nice.org.uk/guidan
ce/ng122.
Patz Jr EF, Greco E, Gatsonis C et al. Lung cancer incidence and mortality 
in National Lung Screening Trial participants who underwent low-­dose CT 
prevalence screening: a retrospective cohort analysis of a randomised, 
multicentre, diagnostic screening trial. Lancet Oncol 2016; 17:590-599.
Ru Zhao Y, Xie X, de Koning HJ et al. NELSON lung cancer screening study. 
Cancer Imaging 2011; 11 Spec No A:S79-84.
Schiller JH. A new standard of care for advanced lung cancer. N Engl J Med. 
2018; 378:2135-2137. 
BRONCHIECTASIS
Bronchiectasis describes abnormal and permanently dilated air­
ways. The disease is characterized by a vicious circle of neutrophilic 
inflammation, recurrent infection and damage to the airway. This 
further impairs mucociliary clearance, and persistent inflammation 
leads to impairment of immunity.
Bronchiectasis is associated with a number of diseases but a 
cause will only be found in around 50% of cases. Little is known 
about the epidemiology and there is a wide variation in reported 
incidence. Bronchiectasis related to cystic fibrosis (see p. 983) is 
generally considered a separate entity.
Aetiology
The causes of bronchiectasis are listed in Box 28.57. Globally, TB 
is the leading cause. Bronchiectasis associated with other lung dis­
eases - in particular, COPD - is becoming increasingly recognized. 
Clinical features
These are shown in Box 28.58. 
Investigations
The aims of investigation are to confirm the diagnosis, rule out 
an underlying cause, look for reversible factors and exclude 
complications.
 • HRCT scanning is the investigation of choice. Characteristically, 
non-­tapering ''tram track'' airways and an increased bronchoar­
terial ratio termed the ''signet ring'' sign can be seen (Fig. 28.35).
 • Chest X-­ray may often be normal but tram track airways, ring 
shadows and cysts may be seen.
 • Sputum examination is useful for a focused antibiotic treatment 
plan, as well as the exclusion of non-­tuberculous mycobacterial 
disease. Extended microbiological culture is often required and 
needs to be specifically requested.
 • Immune assessment would include immunoglobulins and re­
sponses to Hib, tetanus and pneumococcal vaccines as base­
line tests. Second-­line immunological investigation by an immu­
nologist may be necessary.
 • Sweat test and cystic fibrosis genetic assessment (see p. 984) 
should be carried out for all patients under 40, but also for patients 
at any age where there is a high index of suspicion.
 • Nasal nitric oxide is a useful test for screening for primary ciliary 
dyskinesia (PCD). It is very low in PCD. Further ciliary investiga­
tion in a specialist centre may be required.
 • Total IgE and Aspergillus-­specific IgE or Aspergillus skin-­
prick testing should be done to exclude allergic bronchopulmo­
nary aspergillosis. 
Management
Therapy can broadly be divided into airway clearance, anti-­
inflammatories, and treatment of infection and complications.
Airway clearance
Daily airway clearance therapies are advised. The activated cycle of 
breathing technique, autogenic (self-­)drainage and postural drain­
age are popular modalities. A number of devices are available to 
assist, such as the Flutter or Acapella, which provide positive expi­
ratory pressure with or without airway oscillation.
Nebulized hypertonic saline is also approved for use in bronchi­
ectasis; it works as a mucoactive agent. 
Anti-­inflammatories
Long-­term azithromycin has an immunomodulatory effect and has 
been demonstrated to reduce exacerbation frequency. Inhaled cor­
ticosteroids are beneficial to some patients. 
Treatment of infection
Treatment of exacerbations usually lasts 2 weeks and is based 
on previously obtained microbiological information. When', 5949),
   ('dbe4bcc5-5079-5d1a-bb4d-4310e3f2f5ed', 'KUMAR_CLARK_10_2017', 'KC-C28', 983, 1001, 0, '28
Bronchiectasis  983
Pseudomonas aeruginosa is being treated, dual therapy is often 
used where there are multi-­resistant pathogens and where mul­
tiple antibiotic courses would be expected. High-­dose cipro­
floxacin (750 mg twice daily) is a useful oral drug for treatment of 
Pseudomonas. H. influenzae infection is common in bronchiecta­
sis and usually responds to oral antibiotics such as amoxicillin, 
co-­amoxiclav or doxycycline. Some multi-­resistant species need 
intravenous cephalosporin treatment.
Experience in cystic fibrosis has promoted the use of aggres­
sive antibiotic strategies in bronchiectasis, with eradication therapy 
and chronic suppressive nebulized therapy with colistimethate or an 
aminoglycoside for P. aeruginosa (see p. 984).
Rotating oral antibiotic regimes are no longer recommended 
routinely. Long-­term quinolones should be avoided. 
Treatment of complications
 • Pulmonary rehabilitation should be offered to patients with a re­
duced exercise capacity and breathlessness.
 • Massive haemoptysis is a life-­threatening medical emergency; 
treatment is resuscitation with airway protection until bronchial 
artery embolization can be performed to control the bleeding. If 
this is not successful, surgery may be required.
 • Treatment of Aspergillus lung disease and non-­tuberculous my­
cobacteria is covered on page 993.
 • Respiratory failure should be treated with oxygen and non-­
invasive ventilation. Suitable patients should be referred to a 
transplant centre.
 • Surgery is used for localized disease. 
Prognosis
Prognosis is undefined and obviously quite variable, depending on 
disease severity. A low FEV1 and infection with P. aeruginosa are 
associated with a poorer outcome. 
Cystic fibrosis
Cystic fibrosis (CF) is an autosomal recessive condition. In the UK 
the birth prevalence is 1 in 2500 and the carrier rate is 1 in 25. 
Prevalence is a little lower in North America, rates being much 
lower in the non-­Caucasian population. CF no longer causes most 
patients to die in childhood: survival has improved dramatically. 
The current expected median survival is now around 47 years. CF 
is a multisystem disease, although respiratory problems are usu­
ally the most prominent. A vicious circle of mucus stasis, inflam­
mation and infection leads to respiratory failure and death in the 
majority of patients. Most individuals with CF also have pancreatic 
insufficiency. 
Congenital
 • Deficiency of bronchial wall elements
 • Pulmonary sequestration 
Mechanical bronchial obstruction
Intrinsic
 • Foreign body
 • Inspissated mucus
 • Post-­tuberculous stenosis
 • Tumour 
Extrinsic
 • Lymph node
 • Tumour 
Postinfective bronchial damage
 • Bacterial and viral pneumonia, including pertussis, measles and 
aspiration pneumonia 
Granuloma
 • Tuberculosis, sarcoidosis 
Diffuse diseases of the lung parenchyma
 • e.g. Idiopathic pulmonary fibrosis 
Immunological over-­response
 • Allergic bronchopulmonary aspergillosis
 • Post-­lung transplant
 • Graft-­versus-­host disease 
Immune deficiency
Primary
 • Panhypogammaglobulinaemia
 • Selective immunoglobulin deficiencies (IgA and IgG2) 
Secondary
 • Human immunodeficiency virus and malignancy 
Mucociliary clearance defects
Genetic
 • Primary ciliary dyskinesia (Kartagener''s syndrome with dextrocardia and 
situs inversus)
 • Cystic fibrosis 
Acquired
 • Young''s syndrome - azoospermia, sinusitis
Box 28.57 Causes of bronchiectasis
 • Cough: usually persistent
 • Sputum production: large amounts and purulent
 • Breathlessness: as disease progresses
 • Haemoptysis: usually a sign of infection; streaking is common but mas­
sive haemoptysis is a rare medical emergency
 • Infection: usually characterized by increased sputum volume and 
increased purulence
 • Pleuritic chest pain: can be a feature of infection, as well as fever and 
systemic upset
 • Coarse crackles: heard on auscultation but examination can be normal
 • Clubbing: especially in cystic fibrosis
Box 28.58 Symptoms and signs in bronchiectasis
Fig. 28.35  CT scan showing bronchiectasis.  Note the dilated 
bronchi with thickened wall, which are larger than adjacent arteries, 
giving a signet ring appearance.', 4233),
   ('f1c0307f-a2ca-5ebb-9dc0-386f4cefa22a', 'KUMAR_CLARK_10_2017', 'KC-C28', 984, 1002, 0, '28
984  Respiratory disease 
Pathogenesis
The CF gene is located on the long arm of chromosome 7 at position 
31.2 (see p. 18). Mutations lead to abnormalities in the production 
of the cystic fibrosis transmembrane conductance regulator (CFTR) 
protein. This protein is expressed in the apical membrane of epithe­
lial cells and acts as a chloride channel. Over 1000 mutations have 
been identified, most of them rare. The F508del mutation is the most 
common, accounting for around 70% of cases. Mutations have been 
divided into different classes, depending on their effect on CFTR (Box 
28.59). This classification is used therapeutically, with new CF treat­
ments aimed at improving CFTR function. Ivacaftor was the first drug 
available for CF that improves CFTR function.
In the lungs, CFTR dysfunction leads to dehydrated airway 
surface liquid, mucus stasis, airway inflammation and recurrent 
infection. This process originates in the small airways, leading to 
progressive airway obstruction and bronchiectasis (Fig. 28.36). 
Clinical features and complications
CF is a multisystem disease but in 90% of cases the eventual cause 
of death is related to respiratory disease. Pancreatic insufficiency 
occurs in the majority of patients and CF-­related diabetes is becom­
ing increasingly common as survival improves, occurring in up to 
50% of older adults with CF. Liver disease occurs in around 20% 
of the CF population and can lead to cirrhosis in around 2%. Clini­
cal manifestations and complications are summarized in Box 28.60. 
Diagnosis
Most new CF diagnoses are currently made at newborn screening. 
The test involves measuring immunoreactive trypsinogen at the 
time of the neonatal heel-­prick test. If the concentration is raised, 
formal testing is performed.
Aside from neonatal screening, diagnosis for children and adults 
is based on a combination of:
 • Common clinical features (see Box 28.60).
 • CFTR functional testing. The sweat test (pilocarpine iontopho­
resis) measures chloride concentration and is the test routinely 
performed. The normal range is <30 mmol/L, with borderline 
cases at 30-60 mmol/L. These cases often represent patients 
with a milder ''atypical'' phenotype. In difficult cases, nasal po­
tential difference can be measured.
 • Confirmatory genetic testing. 
Management
Patients with CF should be managed in a specialist centre by a mul­
tidisciplinary group of experienced healthcare professionals. They 
should be seen at least every 3 months and have an annual review. 
Lung function (FEV1) and body mass index (BMI) should be recorded 
at every appointment, as they have prognostic importance.
Pulmonary disease
The aim of chronic pulmonary therapies is to reduce FEV1 decline, 
daily symptoms and exacerbation frequency.
 • Airway clearance techniques are a vital part of CF treatment 
regimens, taught to patients and their caregivers by specialist 
respiratory physiotherapists. Techniques include percussion, 
vibration, deep breathing and forced coughing; there is no con­
sensus on the best type and patient choice is the main factor.
 • Nebulized therapy:
 
• Recombinant human DNase (rhDNase) works by lysing bac­
terial DNA and reducing sputum viscosity; it is advised for 
routine treatment from early childhood (regardless of disease 
status). There is clear evidence of improvement in lung dis­
ease and therapy may influence survival.
 
• Hypertonic saline works as an osmotic agent to draw water 
to the cell surface and reduce sputum viscosity.
 
• Inhaled mannitol also increases mucociliary clearance.
 • Anti-­inflammatory treatment with long-­term azithromycin is 
widely used in CF and has an immunomodulatory effect. 
Respiratory infection
Spread of respiratory infection is a great threat to CF patients. Clin­
ics are microbiologically cohorted, patients are managed in single 
rooms and no patient social events are organized.
Class
CFTR effect
Mutation example
I
Protein synthesis defect. No 
functional CFTR
G542X, R553X
II
Folding/trafficking defect. Does not 
reach apical membrane
F508del
III
Gating defect
G551D
IV
Conductance impairment due to 
narrow channel
R117H
V
Splicing defect
3849+10kbC>T
VI
Reduced stability
4326delTC
Box 28.59 CFTR abnormalities in CF
&)75''\VIXQFWLRQ
''HK\GUDWHGDLUZD\VXUIDFHOLTXLG
0XFXVVWDVLV
,QIHFWLRQ
%URQFKLHFWDVLV
Fig. 28.36  Cystic fibrosis: pathogenesis of lung disease.
Respiratory
 • Recurrent respiratory infection
 • Chronic daily cough and sputum production
 • Breathlessness
 • Nasal polyps
 • Haemoptysis (sometimes massive)
 • Pneumothorax
 • Respiratory failure and cor pulmonale
 • Recurrent sinusitis 
Gastrointestinal
 • Failure to thrive in infancy and low body mass index in adults
 • Meconium ileus in infancy
 • Distal intestinal obstruction syndrome
 • Steatorrhoea secondary to pancreatic insufficiency
 • Cystic fibrosis-­related liver disease and cirrhosis
 • Increased risk of gastrointestinal malignancy 
Other
 • Cystic fibrosis-­related diabetes
 • Male infertility
 • Osteoporosis
 • Arthropathy
Box 28.60 Clinical features and complications of cystic 
fibrosis', 5145),
   ('9de7dae2-ce7d-547a-addb-33cbc4b43eaf', 'KUMAR_CLARK_10_2017', 'KC-C28', 985, 1003, 0, '28
Interstitial Lung Diseases  985
P. aeruginosa infection is common in patients with CF and is 
associated with accelerated lung function decline. Eradication is 
the treatment aim. A combination of nebulized colistimethate and 
oral ciprofloxacin, or inhaled tobramycin, can be given. Long-­term 
nebulized suppression therapy with these medications is also used 
to improve respiratory health.
Other organisms, such as Burkholderia cepacia, meticillin-­resistant 
Staph. aureus (MRSA) and Stenotrophomonas maltophilia, have been 
associated with worsening respiratory outcomes and so eradication 
regimes for these bacteria are being used. Non-­tuberculous myco­
bacterial disease, in particular M. abscessus, can be associated with 
a rapid decline and active infection may preclude transplantation.
In exacerbations, intravenous antibiotic therapy is based on pre­
vious infection history. For Pseudomonas, a combination of a β-­
lactam antibiotic such as ceftazidime with an aminoglycoside such 
as tobramycin would be the first-­line choice. In vitro sensitivities are 
less useful in CF. Many CF patients have a permanently implanted 
venous access device for delivery of intravenous therapy. 
Advanced disease
Respiratory failure should be treated with oxygen and NIV. Patients 
should be referred for consideration of lung transplantation when 
FEV1 falls to around 30% predicted. In end-­stage disease, palliative 
care is an essential part of management. This can be challenging 
when patients are on an active waiting list for a lung transplant. 
Non-­respiratory complications
Pancreatic enzymes and vitamin supplements are used to treat 
patients with pancreatic insufficiency. Close attention is paid to 
diet and calorie supplementation. Overnight gastric feeding may be 
required to maintain BMI in some patients.
CF-­related diabetes will often require treatment with insulin and 
is screened for at annual review. It is distinct from type 1 and type 
2 diabetes. Osteoporosis is screened for and treated. Fertility treat­
ment is available for men with CF who are infertile. Women with CF 
who become pregnant should be monitored very closely and deliver 
in a recognized CF centre. 
The future
CFTR modulation has proved to be a major therapeutic advance, 
and studies of therapies for the F508del mutation are ongoing. 
Recently, lumacaftor (a CFTR corrector) in combination with iva­
caftor has been shown to be beneficial in patients with p.Phe508del 
CFTR mutation. It is now widely available in the USA but not NICE-­
approved in UK, where it is given only as compassionate use. Tri­
als are ongoing of triple therapy (using lumacaftor, ivacaftor and 
another agent that also improves CFTR function), which shows ini­
tial promise.
Further reading
Chambers JD, Chotirmall SH. Bronchiectasis: new therapies and new 
perspectives. Lancet Respir Med 2018; 6:715-726.
Elborn JS. Cystic fibrosis. Lancet 2016; 388:2519-2531.
Flume PA, Chalmers JD, Olivier KN. Advances in bronchiectasis: endotyping, 
genetics, microbiome, and disease heterogeneity. Lancet 2018; 392:880-890.
Grasemann H. Modulator therapy for cystic fibrosis. N Engl J Med 2017; 
377:2085-2088. 
INTERSTITIAL LUNG DISEASES
This heterogeneous group of conditions are also referred to as 
diffuse parenchymal lung diseases and account for about 15% 
of respiratory clinical practice. They are characterized by varying 
degrees of inflammation and fibrosis, initially affecting the intersti­
tium of the lung and typically presenting with exertional dyspnoea, 
with or without cough. A classification is shown in Fig. 28.37.
Sarcoidosis
Sarcoidosis is a multisystem granulomatous disorder; it commonly 
affects young adults and typically presents with bilateral hilar lymph­
adenopathy, pulmonary infiltration and skin or eye lesions. 
Epidemiology and aetiology
Sarcoidosis is a common disease of unknown aetiology that is 
often detected on routine chest X-­ray. It is most common in North­
ern Europe (annual incidence 5-40/100 000) but uncommon in 
Japan (incidence 1-2/100 000). It occurs more frequently in Afro-­
Caribbean patients, who are also more likely to develop extrapul­
monary or chronic disease. There is a female preponderance with a 
peak incidence in the third and fourth decades. There is no relation 
to any histocompatibility antigen but first-­degree relatives (particu­
larly Caucasians) have an increased risk of developing sarcoidosis. 
Immunopathology
 • Typical sarcoid granulomas consist of focal accumulations of 
epithelioid cells, macrophages and lymphocytes, mainly T cells.
 • There is depressed cell-­mediated reactivity to tuberculin; the 
Mantoux test is usually negative. There is overall lymphopenia; 
circulating T lymphocytes are low but B cells are slightly increased.
 • Bronchoalveolar lavage shows a great increase in the overall 
number of cells; a lymphocytosis (particularly CD4+ T-­helper 
cells) is common.
 • Transbronchial biopsies show infiltration of the alveolar walls 
and interstitial spaces with leucocytes, mainly T cells, prior to 
granuloma formation. 
Clinical features
Sarcoidosis can affect any organ (Box 28.61) but has a predilection 
for the lungs (involvement in up to 90%). Presentation may be with 
respiratory symptoms but it is not unusual for the diagnosis to be 
made incidentally on chest X-­ray. Common extrathoracic manifes­
tations include eye, skin or lymph node involvement, and constitu­
tional upset with fatigue is a frequent and often refractory symptom.
A typical combination of bilateral hilar lymphadenopathy, ery­
thema nodosum, arthralgia and fever is known as Löfgren''s syn­
drome and usually resolves spontaneously without the need for 
treatment.
In less classic presentations, HRCT may initially suggest sar­
coidosis but tissue biopsy of an affected organ is often sought for 
definitive diagnosis (the presence of non-­caseating granulomas 
being diagnostic). Skin biopsy is comparatively non-­invasive, and 
careful examination for infiltration of scars and tattoos amenable to 
sampling should be undertaken.
Pulmonary manifestations
Although pulmonary involvement may be an incidental finding, 
cough, exertional breathlessness and vague chest discomfort are 
common presentations. Even in symptomatic individuals the chest 
is often clear to auscultation, although wheeze may be evident if 
there is significant involvement of the airways with endobronchial 
disease. There are four radiological stages of lung involvement, 
which help inform prognosis:
 • Stage 1: bilateral hilar lymphadenopathy alone (BHL) - 55-90% 
spontaneous remission.', 6633),
   ('33a35c97-ffa0-51e7-b3c3-50710b0c4deb', 'KUMAR_CLARK_10_2017', 'KC-C28', 986, 1004, 0, '28
986  Respiratory disease 
 • Stage 2: pulmonary infiltrates with BHL - 40-70% spontaneous 
remission.
 • Stage 3: pulmonary infiltrates without BHL - 10-20% spontane­
ous remission.
 • Stage 4: fibrosis.
Patients may present with any stage of disease and do not nec­
essarily progress through the stages sequentially. Moreover, the 
extent of disease on chest X-­ray does not correlate with the degree 
of impairment on pulmonary function testing.
Bilateral hilar lymphadenopathy
Symmetrical BHL is a characteristic feature of sarcoidosis and is 
usually asymptomatic. Occasionally, it is associated with a dull ache 
in the chest, malaise and a mild fever. The differential diagnosis of 
BHL includes:
 • Lymphoma: this rarely affects the hilar lymph nodes in isolation.
 • Pulmonary TB: hilar lymph nodes are usually enlarged asym­
metrically.
 • Carcinoma of the bronchus with malignant spread to the hilar 
lymph nodes: again, this is rarely symmetrical. 
Pulmonary infiltration
Although the lung fields may appear normal on plain chest X-­ray, 
the lung parenchyma is frequently involved, as shown by CT scan­
ning (Fig. 28.38), transbronchial biopsy and bronchoalveolar lavage. 
Symptoms may be minimal (or even absent), despite quite marked 
radiographic abnormalities. Progressive disease may lead to irre­
versible fibrosis in up to 20% of cases. The principal differential 
diagnoses are TB, pneumoconiosis, idiopathic pulmonary fibrosis 
and hypersensitivity pneumonitis. 
Extrapulmonary manifestations
Sarcoidosis can affect any organ. Cutaneous sarcoidosis and ocu­
lar sarcoidosis are the most common extrapulmonary presentations 
but cardiac and CNS involvement are the most important clinically.
Skin lesions
These occur in 10-30% of cases. Sarcoidosis is the most common 
cause of erythema nodosum (see p. 678). Lupus pernio (indurated 
)DPLOLDO
±
1RQIDPLOLDO
!
''LIIXVHSDUHQFK\PDO
OXQJGLVHDVH
''3/''
,GLRSDWKLFLQWHUVWLWLDO
SQHXPRQLDV
,,3V
VHH%R[
*UDQXORPDWRXV
6DUFRLGRVLV
+\SHUVHQVLWLYLW\SQHXPRQLWLV
,QIHFWLRQVHJ7%
9DVFXOLWLV
5DUHUFDXVHV
/\PSKDQJLROHLRP\RPDWRVLV
/DQJHUKDQVFHOOKLVWLRF\WRVLV
$OYHRODUSURWHLQRVLV
.QRZQFDXVHVDVVRFLDWLRQV
$XWRLPPXQHUKHXPDWLFGLVHDVHV
±5$VFOHURGHUPD6/(
±3RO\GHUPDWRP\RVLWLV
([SRVXUHV
±$VEHVWRVVLOLFDEHU\OOLXP
±5DGLDWLRQ
''UXJV
±0HWKRWUH[DWHDPLRGDURQHQLWURIXUDQWRLQ
6PRNLQJUHODWHG
5HVSLUDWRU\EURQFKLROLWLVLQWHUVWLWLDO
OXQJGLVHDVH5%,/''
''HVTXDPDWLYHLQWHUVWLWLDO
SQHXPRQLD'',3
&KURQLFILEURVLQJ
,GLRSDWKLFSXOPRQDU\ILEURVLV,3)
1RQVSHFLILFLGLRSDWKLF
LQWHUVWLWLDOSQHXPRQLD16,3
$FXWHVXEDFXWHILEURVLQJ
&U\SWRJHQLFRUJDQL]LQJSQHXPRQLD
&23
$FXWHLQWHUVWLWLDOSQHXPRQLD$,3
Fig. 28.37  Classification of the interstitial lung diseases.  RA, rheumatoid arthritis; SLE, systemic 
lupus erythematosus; TB, tuberculosis.
Constitutional
 • Fever
 • Weight loss
 • Fatigue 
Reticuloendothelial
 • Splenomegaly
 • Lymphadenopathy 
Respiratory
 • Stage 1-4 pulmonary 
involvement
 • Cough
 • Dyspnoea
 • Wheeze 
Hepatic
 • Deranged liver function tests
 • Hepatomegaly 
Ocular
 • Anterior uveitis
 • Keratoconjunctivitis sicca 
Hypercalcaemia/
hypercalciuria
 • Hypercalciuria
 • Nephrocalcinosis
 • Calculi
 • Tubulointerstitial nephritis 
Cutaneous
 • Erythema nodosum
 • Lupus pernio 
Neurological
 • Cognitive dysfunction
 • Headache
 • Cranial nerve palsies
 • Mononeuritis multiplex
 • Peripheral neuropathy
 • Seizures 
Cardiac
 • Arrhythmias
 • Heart block
 • Cardiomyopathy
 • Sudden death
Box 28.61 Clinical presentations of sarcoidosis', 3676),
   ('c1ff4a82-4649-51b7-a745-7ac0778a6ffe', 'KUMAR_CLARK_10_2017', 'KC-C28', 987, 1005, 0, '28
Interstitial Lung Diseases  987
erythematous or violaceous papules or plaques, Fig. 28.39) may be 
seen over the face and ears. 
Eye lesions
In 5% of patients, anterior or, less commonly, posterior uveitis 
presents with misting of vision, a painful, red eye or progressive 
loss of vision. Asymptomatic uveitis may be found in up to 25% 
of patients with sarcoidosis and ophthalmological assessment 
should be considered in all patients with a new diagnosis of sar­
coidosis. Keratoconjunctivitis sicca and lacrimal gland enlarge­
ment also occur. 
Metabolic manifestations
Hypercalcaemia and hypercalciuria can lead to the development of 
renal calculi, nephrocalcinosis and, ultimately, renal failure. 
Central nervous system
CNS involvement is rare (2%) but can lead to severe neurological 
disease (see p. 868). 
Bone and joint involvement
Arthralgia without erythema nodosum is seen in 5% of cases. Bone 
cysts with associated swelling, particularly affecting the digits, may 
be seen on X-­ray. 
Hepatosplenomegaly
Mild derangement of liver function tests is common and granulomas 
are seen in the majority of biopsy specimens, although these find­
ings are rarely of clinical consequence. Progression to portal hyper­
tension or liver failure is uncommon. 
Renal involvement
Sarcoidosis classically causes a granulomatous tubulointerstitial 
nephritis, although kidney damage secondary to hypercalcaemia 
and stone formation may also be seen. 
Cardiac involvement
Ventricular dysrhythmias, conduction defects and cardiomyopathy 
with congestive cardiac failure are rare (3%). Severity ranges from 
benign rhythm disturbance to sudden cardiac death. All patients 
with sarcoidosis should have an ECG at presentation. 
Investigations
 • Imaging. Chest X-­ray is the initial modality for staging, followed 
by HRCT for assessment of parenchymal involvement. This may 
show nodules of up to 10 mm diameter that form a characteristic 
''beading'' appearance along airways, vessels and fissures; nod­
ules may aggregate into larger nodules or masses of up to 3 cm; 
there may be increased reticulation due to septal thickening; in 
severe cases fibrotic honeycombing is seen.
 • Full blood count. There may be a mild normochromic, normo­
cytic anaemia with raised ESR.
 • Biochemistry. Renal involvement is occasionally found and 
may require renal biopsy and first-­line treatment. Hypercalcae­
mia occurs in 10-20% and hypercalciuria in 30-50%. Activated 
macrophages in lung and lymph nodes are able to hydroxylate 
vitamin D directly (independent of parathyroid hormone levels), 
leading to increased intestinal absorption of dietary calcium. 
Measurement of 24-­hour urinary calcium excretion should be 
performed at presentation.
 • Serum ACE level. This is elevated in over 75% of patients with 
untreated sarcoidosis. Raised (but lower) levels are also seen in 
patients with lymphoma, pulmonary TB, asbestosis and silico­
sis, limiting the diagnostic value of the test. The utility of serum 
ACE in monitoring disease activity and response to treatment is 
contentious.
$
%
Fig. 28.38  CT chest showing sarcoidosis.  (A) Soft tissue settings demonstrate bilateral hilar lymphad­
enopathy (arrowed). (B) Lung settings demonstrate multiple small nodules and reticulation in both lungs.
Fig. 28.39  The lupus pernio form of sarcoidosis.  There are infil­
trated violaceous plaques on the nose, cheeks, and ears. This girl had 
hoarseness owing to her laryngeal involvement with sarcoidosis and was 
left with severe scarring after treatment. (From Paller AS, Mancini AJ. 
Hurwitz Clinical Pediatric Dermatology: A Textbook of Skin Disorders of 
Childhood and Adolescence, 5th edn. Elsevier Inc.; 2016; Fig. 25-­20.)', 3728),
   ('12cfa80f-2a31-54f4-b52e-b3a0e9636d24', 'KUMAR_CLARK_10_2017', 'KC-C28', 988, 1006, 0, '28
988  Respiratory disease 
 • Cardiac tests. ECG and echocardiogram should be performed 
at presentation. If these raise concern about underlying cardiac 
sarcoidosis, then further investigation is with cardiac MRI.
 • Bronchoscopy. Bronchoalveolar lavage typically shows a lympho­
cytosis with raised CD4 : CD8 ratio. Transbronchial biopsy of the 
lung parenchyma is positive in up to 90% of cases of pulmonary 
sarcoidosis. Pulmonary non-­caseating granulomas are found in ap­
proximately 50% of patients with extrapulmonary sarcoidosis who 
have a normal chest X-­ray. If, in addition, endobronchial biopsy 
(EBUS) of thoracic lymph nodes is performed, this may significantly 
increase the yield, even if the macroscopic appearances are normal.
 • Lung function tests. These show a restrictive lung defect with 
reduced gas transfer in patients with parenchymal infiltration or 
fibrosis. However, an obstructive defect may be seen in endo­
bronchial disease and a mixed pattern is also possible. Lung 
function is usually normal in patients with isolated hilar adeno­
pathy or extrapulmonary disease. 
Prognosis and management
The natural history of sarcoidosis is unpredictable and varies from 
spontaneous remission to inexorable progression and death in a 
small number (1-5%). Even once remission has been achieved, 
relapses are common. Worse outcomes are seen in patients of Afro-­
Caribbean and Asian descent, and those presenting with extrathor­
acic disease. Systemic treatment is indicated for hypercalcaemia 
and extrathoracic major organ involvement, particularly neurologi­
cal, cardiac or ocular disease resistant to topical therapy. Treatment 
of pulmonary sarcoidosis is less clear-­cut, as spontaneous resolu­
tion is frequently seen, typically within the first 6 months. Moreover, 
although corticosteroids improve radiographic appearances, this is 
not consistently reflected in improved lung function tests. Treatment 
is therefore reserved for patients with troublesome symptoms, dete­
riorating lung function or radiological evidence of disease progres­
sion. First-­line treatment is with prednisolone (or equivalent) 0.5 mg/
kg for 4-6 weeks, gradually tapering to a maintenance dose for at 
least 12 months. Alternative immunosuppressants, including meth­
otrexate, azathioprine and hydroxychloroquine, have been used in 
place of, or in addition to, prednisolone. Relapses are common on 
withdrawal of therapy. Lung transplantation should be considered 
for suitable patients with stage IV disease and respiratory failure. 
Idiopathic interstitial pneumonias
The terminology used to describe the idiopathic interstitial pneu­
monias can be confusing but a distinction must be made between 
subgroups, as there are significant differences in terms of prognosis 
and treatment options. Clinical patterns usually link to particular his­
tological subtypes; their classification is shown in Box 28.62.
Idiopathic pulmonary fibrosis
Idiopathic pulmonary fibrosis (IPF) is the most common of the idiopathic 
interstitial pneumonias. It is a progressive and ultimately fatal disease 
of unknown cause. There is significant worldwide variation in reported 
prevalence but the incidence appears to be increasing (6.8-8.8/100 000 
in the USA). The onset is usually in the patient''s sixties and is rare below 
the age of 50. Males are twice as likely to be affected. 
Pathology
Usual interstitial pneumonia (UIP) is the histological finding in IPF. 
The key feature is a heterogenous appearance with areas of normal 
lung punctuated by areas of marked fibrosis, honeycombing mainly 
in subpleural areas and fibroblastic foci (dense proliferations of 
fibroblasts and myofibroblasts). The terms IPF and UIP are often 
used interchangeably but they are not synonymous, as UIP is also 
the primary histological finding in several other diffuse parenchymal 
lung diseases (e.g. pulmonary autoimmune rheumatic disease). 
Pathogenesis
It is thought that repetitive injury to the alveolar epithelium, caused by 
currently unidentified environmental stimuli, leads to the activation of 
several pathways responsible for repair of the damaged tissue. How­
ever, in IPF, the wound healing mechanisms become uncontrolled, 
leading to over-­production of fibroblasts and deposition of increased 
extracellular matrix in the interstitium with little inflammation. The 
structural integrity of the lung parenchyma is therefore disrupted: 
there is loss of elasticity and the ability to perform gas exchange is 
impaired, leading to progressive respiratory failure. 
Clinical features
Patients typically present with insidious onset of progressive dys­
pnoea that may be accompanied by cough, with or without sputum 
production. Examination of the chest shows bi-­basal end-­inspiratory 
crackles and therefore it is not uncommon for patients to be mistak­
enly treated for heart failure or recurrent chest infections before the 
diagnosis of IPF is made. Finger clubbing is seen in 25-50% of cases.
Progressive respiratory failure may be complicated by pulmo­
nary hypertension. Stepwise deterioration can occur due to pneu­
mothorax, pulmonary embolism or intercurrent infection, but acute 
exacerbations with no identifiable cause are well recognized and are 
associated with increased mortality. An acute form (also known as 
Hamman-Rich syndrome) occasionally occurs and has a particu­
larly poor prognosis. 
Investigations
 • Respiratory function tests usually show a restrictive pattern 
(FEV1/FVC ratio >70%) with reduced lung volumes and gas 
transfer. However, spirometry may be normal in early disease 
and lung volumes can be preserved in the presence of coexist­
ing emphysema.
Clinical diagnosis
Pathological pattern
Idiopathic pulmonary fibrosis (IPF)
Usual interstitial pneumonia 
(UIP)
Desquamative interstitial 
pneumonia (DIP)
Desquamative interstitial 
pneumonia (DIP)
Respiratory bronchiolitis interstitial 
lung disease (RBILD)
Respiratory bronchiolitis inter­
stitial lung disease (RBILD)
Acute interstitial pneumonia (AIP)
Diffuse alveolar damage (DAD)
Non-­specific interstitial pneumonia 
(NSIP)
Non-­specific interstitial 
pneumonia (NSIP)
Cryptogenic organizing 
pneumonia (COP)
Organizing pneumonia (OP)
Lymphoid interstitial pneumonia 
(LIP)
Lymphoid interstitial 
pneumonia (LIP)
Box 28.62 Classification of idiopathic interstitial 
pneumonias
(From ATS/ERS. American Thoracic Society/European Respiratory Society International 
multidisciplinary consensus classification of the idiopathic interstitial pneumonias. Am J 
Respir Crit Care Med 2002; 165:277.)', 6599),
   ('fdbc3ec6-c5e7-581e-b7f8-29e1cdaa9dac', 'KUMAR_CLARK_10_2017', 'KC-C28', 989, 1007, 0, '28
Interstitial Lung Diseases  989
 • Blood tests, including antinuclear antibodies (ANA) and rheu­
matoid factor (RF), are performed to exclude autoimmune 
rheumatic disease but there is no specific serological test 
for IPF.
 • Chest X-­ray shows small-­volume lungs with increased reticular 
shadowing at the bases but may be normal in early disease.
 • HRCT is the imaging modality of choice. A confident diagnosis 
of IPF may be made in patients with:
 
• Basal distribution: abnormalities are more pronounced at 
the bases.
 
• Subpleural reticulation: reticulation is most evident in the 
lung peripheries.
 
• Traction bronchiectasis: the fibrotic process distorts the 
normal lung architecture, pulling the airways open and caus­
ing bronchiectasis.
 
• Honeycombing: there are basal layers of small, cystic air­
spaces with irregularly thickened walls composed of fibrous 
tissue (Fig. 28.40).
 • Bronchoalveolar lavage is necessary only if an infective or ma­
lignant cause is suspected. A differential cell count may lend 
support to an alternative diagnosis: a lymphocytosis is sugges­
tive of hypersensitivity pneumonitis, whereas a neutrophilic pat­
tern (neutrophils >3%) is commonly seen in IPF.
 • Histological confirmation is necessary in some patients. 
Surgical lung biopsy, usually via VATS, is the most reliable 
method for obtaining diagnostic histological samples; trans­
bronchial biopsy can be undertaken bronchoscopically but 
only obtains small samples. 
Differential diagnosis
The main differential diagnosis for IPF is an alternative interstitial 
lung disease. Other differentials for the chest X-­ray appearances 
include interstitial pulmonary oedema, infection and lymphangitis 
carcinomatosa. 
Prognosis and management
The median survival time for patients with IPF is 2-5 years. Serial 
lung function testing is used to monitor disease progression and 
a 10% decline in FVC or 15% decline in gas transfer (TLCO) in 
the first 6-12 months confers a worse prognosis. Periods of sta­
bility may be interspersed with spells of more accelerated decline 
but failure to recover back to baseline following these episodes 
is common. Mortality is increased following acute exacerbations.
Immunosuppression is generally avoided in IPF and steroids are 
no longer recommended in confirmed disease.
Pirfenidone, an antifibrotic agent, has been shown to slow the 
rate of FVC decline, with the most common side-­effects being a 
reversible photosensitive rash and gastrointestinal disturbance. 
Other treatments include nintedanib, an intracellular inhibitor of 
tyrosine kinases.
Gastro-­oesophageal reflux disease should be treated if 
symptomatic.
Even with treatment, IPF is a life-­limiting disease and transplant 
assessment should be undertaken in accordance with local guide­
lines. All patients should have their need for supportive care evalu­
ated with respect to oxygen therapy, pulmonary rehabilitation and 
palliative care input. 
Other idiopathic interstitial pneumonias
These are described in Box 28.63. 
Hypersensitivity pneumonitis
Hypersensitivity pneumonitis (HP) is caused by an allergic reaction 
affecting the small airways and alveoli in response to an inhaled 
antigen or occasionally following ingestion of a causative drug. 
Common antigens are illustrated in Box 28.64.
One of the most common causes worldwide is farmer''s lung, 
which can affect up to 9% of farmers in humid climates. Cigarette 
smokers have a lower risk of developing HP due to decreased anti­
body reaction to the antigen, but once established, smoking may 
lead to a more chronic or severe disease course.
Pathogenesis
Histological features include chronic inflammatory infiltrates and 
poorly defined interstitial granulomas, together with interstitial fibro­
sis and honeycomb change in chronic disease.
The allergic response to the inhaled antigen involves both 
cellular immunity and deposition of immune complexes, causing 
foci of inflammation through activation of complement via the 
classical pathway. 
Clinical features
HP can be categorized according to the time course of symptoms, 
as determined by duration and intensity of exposure. Symptoms 
include weight loss, malaise, dyspnoea and cough. Auscultation 
reveals inspiratory squeaks due to bronchiolitis, and bilateral fine 
crackles. Wheeze is uncommon.
 • Acute: symptom onset 4-6 h following exposure. Fever is com­
mon and patients may be mistakenly diagnosed with a chest 
infection. Resolution occurs 24-48 h following removal from the 
inciting antigen.
 • Subacute: usually occurs with intermittent or lower-­level expo­
sure. Improvement is seen in weeks to months following removal 
from exposure.
 • Chronic: usually no history of preceding acute symptoms. In­
sidious onset of respiratory and constitutional symptoms is typi­
cal. Finger clubbing may be present. Progression to irreversible 
fibrosis is associated with increased mortality. 
Fig. 28.40  CT chest demonstrating idiopathic pulmonary fibro­
sis.  There is subpleural reticulation and honeycombing at both lung 
bases.', 5095),
   ('0fab6b70-a623-56c0-8867-3f8fb4a7ae60', 'KUMAR_CLARK_10_2017', 'KC-C28', 990, 1008, 0, '28
990  Respiratory disease 
Disease
Situation
Antigens
Farmer''s lung
Forking mouldy hay or any other mouldy vegetable 
material
Thermophilic actinomycetes, e.g. Micropolyspora faeni
Fungi, e.g. Aspergillus umbrosus
Bird fancier''s lung
Handling pigeons, cleaning lofts or budgerigar cages
Proteins present in the ''bloom'' on the feathers and in excreta
Maltworker''s lung
Turning germinating barley
Aspergillus clavatus
Humidifier fever
Contaminated humidifying systems in air 
conditioners or humidifiers in factories (especially 
in printing works)
Possibly a variety of bacterium or amoeba (e.g. Naegleria 
gruberi )
Thermophilic actinomycetes
Mushroom worker''s lung
Turning mushroom compost
Thermophilic actinomycetes
Cheese washer''s lung
Mouldy cheese
Penicillium casei
Aspergillus clavatus
Winemaker''s lung
Mould on grapes
Botrytis
Box 28.64 Some causes of hypersensitivity pneumonitis
IIP
Presentation
HRCT
Pathology
Treatment
Desquamative 
interstitial 
pneumonia (DIP)
Middle-­aged smokers
Men > women
Dyspnoea and cough over weeks to 
months
Widespread ground glass 
opacification
Alveolar spaces filled 
with pigmented 
macrophages (due to 
tobacco smoke)
Smoking cessation - may 
remit spontaneously
Corticosteroids in severe 
or progressive dis­
ease ± additional 
­immunosuppressants
Response generally good
Respiratory 
bronchiolitis 
interstitial lung 
disease (RBILD)
Current or ex-­smokers
Similar to DIP
Centrilobular nodules
Ground glass 
opacification
Pigmented macrophages 
in lumen of respiratory 
bronchioles
Smoking cessation
No clear benefit with corti­
costeroids
Outcome more favourable 
than in DIP
Acute interstitial 
pneumonia (AIP, 
Hamman-Rich 
syndrome)
Dyspnoea and progressive 
respiratory failure over days to 
weeks
Often preceded by viral prodrome
Ground glass 
opacification
Traction bronchiectasis
Consolidation
Septal thickening
Diffuse alveolar damage 
(DAD)
Pulsed i.v. 
­methylprednisolone for 
3 days followed by mainte­
nance oral corticosteroids
Additional 
­immunosuppressants 
may be required
Mortality 50-80%
Non-­specific 
interstitial 
pneumonia 
(NSIP)
Similar to IPF but more indolent 
course
May be associated with connective 
tissue disease
Similar to IPF but 
increased ground 
glass opacification, 
minimal honeycombing
Uniform inflammatory 
i­nfiltrate with or without 
fibrosis (fibrotic vs 
cellular NSIP)
Corticosteroids ± 
additional 
immunosuppressants, 
e.g. azathioprine, cyclo­
phosphamide
Prognosis better with 
­cellular form
Outcome more favourable 
than in IPF
Cryptogenic 
organizing 
pneumonia 
(COP)
Influenza-­like symptoms, dyspnoea, 
cough over weeks to months
Secondary OP may be related to 
connective tissue, autoimmune 
disease or drugs
Bilateral flitting/migratory 
peripheral 
consolidation
Variable ground glass 
opacification
Buds of connective tissue 
(Masson bodies) in 
alveoli and alveolar 
ducts
Usually rapidly responsive 
to corticosteroids but 
relapses common
Lymphoid interstitial 
pneumonia (LIP)
Commonly, middle-­aged women
Insidious dyspnoea, dry cough, 
systemic upset
May be associated with connective 
tissue disease and HIV infection
Ground glass 
opacification
Perivascular cysts
Interstitium infiltrated by 
lymphocytes, 
macrophages and 
plasma cells
Corticosteroids
Anti-­retrovirals in HIV
Mortality up to 38%
Box 28.63 Other idiopathic interstitial pneumonias (IIPs)
HIV, human immunodeficiency virus; HRCT, high-­resolution computed tomography; IPF, idiopathic pulmonary fibrosis.
Investigations
A diagnosis can often be made by maintaining a high index of suspi­
cion and taking a detailed exposure history. Identification of a culprit 
antigen in the context of typical clinical and radiological findings 
often makes lung biopsy unnecessary.
 • Chest X-­ray may be normal in acute and subacute disease. 
When present, abnormalities include diffuse small nodules and 
increased reticular shadowing.
 • HRCT shows nodules with ground-­glass opacity and evidence 
of air trapping. Increased reticulation and honeycomb change', 4037),
   ('ebdbe1ec-eea7-58d1-b2a4-d8d102daaca9', 'KUMAR_CLARK_10_2017', 'KC-C28', 991, 1009, 0, '28
Interstitial Lung Diseases  991
are seen in advanced disease. Abnormalities are most marked in 
the mid or upper zones.
 • Lung function tests are not diagnostic. A restrictive ventilatory 
defect with decreased carbon monoxide gas transfer is seen in 
chronic disease.
 • Precipitating antibodies are present in the serum. One-­quarter 
of pigeon fanciers have precipitating IgG antibodies against pi­
geon protein and droppings in their serum, but only a small pro­
portion have lung disease. Precipitating antibodies are therefore 
evidence of exposure, not disease.
 • Bronchoalveolar lavage shows a lymphocytosis. A low 
CD4 : CD8 ratio can help differentiate HP from sarcoidosis.
 • Lung biopsy demonstrates a lymphocyte-­rich infiltrate with var­
ying degrees of fibrosis, depending on chronicity of disease. 
Differential diagnosis
Although HP due to inhalation of the spores of Micropolyspora faeni 
is common among farmers (farmer''s lung), it is probably more usual 
for these individuals to suffer from asthma related to inhalation of 
antigens from a variety of mites that infest stored grain and other 
vegetable material, such as Lepidoglyphus domesticus, L. destruc­
tor and Acarus siro. 
Management
The key to successful treatment is avoidance of exposure to the 
inciting antigen (if known) and this may be achieved by changes in 
work practice. Pigeon fancier''s lung is more difficult to control, as 
affected individuals remain strongly attached to their hobby. Pred­
nisolone should be initiated in patients whose symptoms persist 
despite withdrawal from the causative antigen, and in severe dis­
ease. Established fibrosis will not resolve and, in some patients, the 
disease may progress inexorably to respiratory failure despite inten­
sive therapy. Farmer''s lung is a recognized occupational disease in 
the UK and sufferers are entitled to compensation, depending on 
their degree of disability. 
Rare interstitial lung diseases
Langerhans cell histiocytosis
This rare disease is characterized histologically by proliferation of 
Langerhans cells. There is a wide variation in clinical presentation, 
from isolated lytic bone lesions to multisystem disease involving 
skin, lymph nodes and major organs (more commonly seen in young 
children). Pulmonary involvement occurs in 10% of cases and is 
strongly associated with cigarette smoking. Recurrent spontane­
ous pneumothorax is seen in up to 25% and is a common mode 
of presentation. HRCT shows characteristic interstitial thicken­
ing, nodules, cysts and honeycombing with mid and upper zone 
predominance, and this may be sufficient for diagnosis in a young 
smoker (typical age 20-40 years). Smoking cessation is essential. 
Various treatment strategies, including corticosteroids, chemo­
therapy agents and the purine analogue cladribine, have been used 
with variable success. Lung transplantation may be considered in 
advanced disease. Outcome varies from spontaneous remission to 
progressive end-­stage fibrosis but overall 5-­year survival is 75%. 
Pulmonary lymphangioleiomyomatosis
Pulmonary lymphangioleiomyomatosis (LAM) is a rare disorder of 
premenopausal women, causing hamartomatous smooth muscle 
infiltration of the lungs. Extrapulmonary involvement, especially with 
renal angiomyolipomas (hamartomas), is common. Some 15% of 
patients with pulmonary LAM have tuberous sclerosis. Presenta­
tion is with dyspnoea, chylous pleural effusions and pneumo­thorax. 
HRCT shows diffuse thin-­walled cysts scattered throughout the 
lungs. Treatment with hormonal manipulation or oophorectomy has 
shown a variable response. Sirolimus (rapamycin) can be effective 
but lung transplantation may be necessary. 
Pulmonary alveolar proteinosis
In this rare disease lipoproteinaceous material accumulates within 
the alveoli. It can be congenital but most cases are acquired and 
appear to have an autoimmune basis, with antibodies directed 
against the cytokine granulocyte-­macrophage colony-­stimulating 
factor (GM-­CSF). The disease mostly affects men and presents with 
progressive exertional dyspnoea and cough. Inspiratory crackles 
are present in 50%. Diagnosis is made by bronchoalveolar lavage, 
which reveals a milky appearance and many large, foamy mac­
rophages but few other inflammatory cells. Initial therapy is with 
whole-­lung lavage. 
Small-­vessel vasculitides
The vasculitides are a group of autoimmune diseases that cause 
inflammation of the large, medium and small blood vessels. The 
small-­vessel vasculitides associated with anti-­neutrophil cyto­
plasmic antibody (ANCA) include granulomatosis with polyan­
giitis (GPA, formerly referred to as Wegener''s granulomatosis), 
microscopic polyangiitis (MPA) and eosinophilic granulomatosis 
with polyangiitis (EGPA, formerly called Churg-Strauss syndrome). 
Staining for ANCA shows either a diffuse pattern (c-­ANCA) with 
antibodies directed against proteinase 3 (PR3), or a perinuclear pat­
tern (p-­ANCA) with antibodies to myeloperoxidase (MPO) (see also 
p. 416). The respiratory tract and kidneys are frequently involved 
and the ESR is often markedly elevated (>100 mm/h).
Granulomatosis with polyangiitis
GPA typically affects older adults and is more common in Cauca­
sians. The c-­ANCA is usually positive with elevated PR3 antibodies. 
The ears and upper respiratory tract are frequently affected with 
bloody nasal discharge, crusting and destruction, sinusitis and otitis 
media. Evidence of glomerulonephritis should be sought on urinaly­
sis (see p. 1352). Respiratory symptoms include cough, dyspnoea 
and pleuritic chest pain. Diffuse alveolar haemorrhage occurs in up 
to 45% and haemoptysis can be life-­threatening. Thoracic imag­
ing characteristically shows multiple nodules that often cavitate, 
areas of consolidation and ground-­glass opacification (which may 
be due to pulmonary haemorrhage). Diagnosis should be confirmed 
with biopsy of the active site but it is sometimes necessary to initi­
ate empirical treatment in acutely unwell patients. Initial immuno­
suppressant therapy is with a combination of glucocorticoids and 
cyclophosphamide, rituximab or methotrexate. 
Microscopic polyangiitis
MPA is primarily associated with p-­ANCA positivity. Presentation 
and treatment are similar to those of granulomatosis with polyangi­
itis. It is diagnosed on tissue biopsy, where the absence of granu­
loma formation differentiates it from GPA. 
Eosinophilic granulomatosis with polyangiitis
EGPA classically presents in early adulthood with allergic rhini­
tis, asthma that is often difficult to control, and peripheral blood 
eosinophilia (>10%); it is ANCA-­positive in up to 60% (usually 
p-­ANCA). Systemic vasculitis subsequently develops, sometimes', 6751),
   ('0e863d0c-eb33-594e-a328-cac3d69612c3', 'KUMAR_CLARK_10_2017', 'KC-C28', 992, 1010, 0, '28
992  Respiratory disease 
many years later. Involvement of skin (tender subcutaneous nod­
ules, petechiae or purpuric lesions), peripheral nerves (mononeuritis 
multiplex), heart, kidneys and gastrointestinal tract may occur. The 
chest X-­ray shows migratory patchy opacities that may be accom­
panied by nodules and pleural effusions. EGPA generally responds 
well to corticosteroids, although additional immunosuppressants 
are required for severe or refractory disease. Occasionally, EGPA 
is ''unmasked'' when oral steroids are withdrawn in patients being 
treated for asthma. 
Anti-­glomerular basement membrane 
disease (Goodpasture''s syndrome)
Anti-­glomerular basement membrane (anti-­GBM) disease is charac­
terized by the triad of pulmonary haemorrhage, glomerulonephritis, 
and the presence of circulating antibodies directed against an anti­
gen intrinsic to the basement membrane of both kidney and lung. 
Respiratory symptoms may precede the onset of glomerulonephritis 
by weeks or months. The chest X-­ray shows transient patchy shad­
ows due to intrapulmonary haemorrhage, although haemoptysis 
can vary from negligible to life-­threatening. The carbon monoxide 
gas transfer is increased due to the presence of haemoglobin in the 
alveoli. The extent of renal recovery depends on early detection and 
treatment. Treatment is with plasmapheresis to remove circulating 
antibodies and immunosuppression (prednisolone and cyclophos­
phamide) to prevent further antibody production. 
Diffuse alveolar haemorrhage
Bleeding into the alveolar spaces is associated with certain drugs, 
infections and autoimmune rheumatic diseases, including vasculitis, 
but can also occur without an identifiable precipitating cause. Hae­
moptysis may be minimal (or even absent), despite significant blood 
loss into the lungs. It is one of the relatively few causes of raised 
carbon monoxide gas transfer (KCO, see p. 943). Gas exchange is 
impaired due to the presence of blood in the alveoli and patients 
may present with severe respiratory failure requiring intensive care 
support. Treatment is directed at the underlying cause, if known. 
Pulmonary manifestations of autoimmune 
rheumatic diseases
Rheumatoid disease
The lungs can be affected by rheumatoid arthritis (RA) and also by some 
of the drugs used in its treatment (Fig. 28.41; see also Box 18.32).
 • Pleural effusions are often unilateral and tend to be chronic. 
Low glucose content is typical but not specific.
 • Pulmonary fibrosis occurring in RA has similar clinical features 
to the idiopathic form of the disease but often follows a more 
chronic course (see p. 443). In patients taking methotrexate, it is 
often impossible to determine whether fibrosis is due to the drug 
or the underlying disease; either way, methotrexate should be 
substituted for an alternative agent.
 • Rheumatoid nodules appearing on the chest X-­ray may be 
single or multiple, ranging in size from a few millimetres to a 
few centimetres. The nodules frequently cavitate. They usually 
produce no symptoms but can give rise to a pneumothorax or 
pleural effusion.
 • Obliterative bronchiolitis causing concentric narrowing of 
the bronchioles is a rare disorder characterized by progressive 
breathlessness and irreversible airflow limitation. Response to 
immunosuppressive therapy is generally poor but macrolide an­
tibiotics may have a role.
 • Cricoarytenoid joint involvement in RA gives rise to dyspnoea, 
stridor and hoarseness. Occasionally, severe obstruction neces­
sitates tracheostomy.
 • Caplan''s syndrome is due to occupational dust inhalation in 
patients with RA; it occurs particularly in coal worker''s pneumo­
coniosis but can by caused by exposure to other dusts, such as 
silica and asbestos. Typically, the chest X-­ray shows rounded 
nodules 0.5-5.0 cm in diameter but progressive fibrosis can 
sometimes occur. These lesions may precede the development 
of arthritis. Rheumatoid factor is positive in the majority of pa­
tients.
 • Drugs used in the treatment of RA can cause pulmonary prob­
lems, e.g. pneumonitis with methotrexate, gold and NSAIDs; 
fibrosis with methotrexate; bronchospasm with NSAIDs; infec­
tions with corticosteroids and methotrexate; and reactivation of 
TB with anti-­TNF therapy. 
Systemic lupus erythematosus
The most common respiratory manifestation is pleurisy, occur­
ring in up to two-­thirds of cases, with or without an effusion (see 
also p. 458), which is usually small and bilateral. Pneumonia also 
occurs, either because of infection or because of the disease 
process itself. In contrast to RA, diffuse pulmonary fibrosis is 
uncommon. 
Systemic sclerosis
Some degree of lung involvement is present in the majority of cases 
of systemic sclerosis, and pulmonary complications are the lead­
ing cause of death (see p. 462). Interstitial fibrosis and pulmonary 
arterial hypertension are the most common pathologies. Serial 
lung function testing can aid early detection. Other complications 
include bronchiectasis and aspiration pneumonitis secondary to 
oesophageal dilation. 
&ULFRDU\WHQRLGDUWKULWLV
5KHXPDWRLG
SQHXPRFRQLRVLV
&DSODQ¶VV\QGURPH
6PDOODLUZD\
GLVHDVH
6PDOOXQLODWHUDO
SOHXUDOHIIXVLRQ
''LIIXVHSXOPRQDU\
ILEURVLV
2EOLWHUDWLYH
EURQFKLROLWLV
1RGXOHVDQG
FDYLWLHV
Fig. 28.41  Respiratory manifestations of rheumatoid dis­
ease.  Many drugs affect the lungs; see Box 18.32.', 5411),
   ('4f27dfc5-da42-597d-86b0-175faf7cb398', 'KUMAR_CLARK_10_2017', 'KC-C28', 993, 1011, 0, '28
Interstitial Lung Diseases  993
Pulmonary infiltration with eosinophilia
This is a group of allergic respiratory conditions, often directed 
against helminths or drugs; common types and characteristics are 
shown in Box 28.65. They range from simple pulmonary eosino­
philia to the often fatal hypereosinophilic syndrome. Simple pulmo­
nary eosinophilia is a relatively mild illness, with a slight fever and 
cough, and usually lasts for less than 2 weeks. If symptoms become 
more prolonged and there is an eosinophilia in the blood, it is then 
called prolonged pulmonary eosinophilia. In both conditions the 
chest X-­ray shows either localized or diffuse opacities. The simple 
form is probably due to a transient allergic reaction in the alveoli. 
Many allergens have been implicated, including Ascaris lumbricoi­
des, Ancylostoma, Trichuris, Trichinella, Taenia and Strongyloides. 
Drugs such as aspirin, penicillin, nitrofurantoin and sulphonamides 
have also been implicated. Often, however, no allergen is identi­
fied. The disease is self-­limiting and no treatment is required, apart 
from withdrawing the identified cause. In the more chronic form, 
all unnecessary treatment should be withdrawn and corticosteroid 
therapy is indicated, with resolution of the disease over the ensuing 
weeks.
Asthmatic bronchopulmonary eosinophilia is characterized 
by the presence of asthma, transient fleeting shadows on the chest 
X-­ray, and blood or sputum eosinophilia. By far the most com­
mon cause worldwide is allergy to Aspergillus fumigatus (see later), 
although Candida albicans and other mycoses may be the inciting 
allergen in a small number of patients. In many, no allergen can be 
identified. Whether these cases are intrinsic or driven by an uniden­
tified extrinsic factor is uncertain. Tropical pulmonary eosinophilia 
is the term reserved for an allergic reaction to microfilaria from 
Wuchereria bancrofti.
Hypereosinophilic syndrome is characterized by eosinophilic 
infiltration in various organs, sometimes associated with an eosino­
philic arteritis. The heart muscle is particularly involved, but pulmon­
ary involvement in the form of a pleural effusion or interstitial lung 
disease occurs in about 40% of cases.
Diseases caused by Aspergillus fumigatus
The various types of lung disease caused by A. fumigatus are illus­
trated in Fig. 28.42.
The spores (diameter 5 mm) are readily inhaled and are present 
in the atmosphere throughout the year. Aspergillus can be grown 
from sputum in up to 15% of patients with chronic lung disease, in 
whom it does not produce active fungal disease. They are a cause 
of extrinsic asthma in atopic individuals.
Allergic bronchopulmonary aspergillosis (asthmatic 
pulmonary eosinophilia)
This rare disease is caused by a hypersensitivity reaction when the 
bronchi are colonized by Aspergillus. It can complicate asthma and 
cystic fibrosis. Proximal bronchiectasis occurs.
Episodes of eosinophilic pneumonia present with a wheeze, cough, 
fever and malaise, associated with expectoration of firm sputum plugs 
containing the fungal mycelium. Occasionally, large mucus plugs oblit­
erate the bronchial lumen, causing collapse of the lung. Left untreated, 
repeated episodes of eosinophilic pneumonia can result in progressive 
pulmonary fibrosis that usually affects the upper zones.
Disease
Symptoms
Blood eosinophils (%)
Multisystem involvement
Duration
Outcome
Simple pulmonary eosinophilia
Mild
10
None
<1 month
Good
Prolonged pulmonary eosinophilia
Mild/moderate
>20
None
>1 month
Good
Asthmatic bronchopulmonary eosinophilia
Moderate/severe
5-20
None
Years
Fair
Tropical pulmonary eosinophilia
Moderate/severe
>20
None
Years
Fair
Hypereosinophilic syndrome
Severe
>20
Always
Months/years
Poor
Box 28.65 Common types and characteristics of pulmonary infiltration with eosinophilia
$OOHUJLFDVSHUJLOORVLV
/DWHU
,QLWLDO
0XFRLGLPSDFWLRQ
$VSHUJLOORPD
,QYDVLYHDVSHUJLOORVLV
8SSHU
OREH
ILEURVLV
$VWKPD
3UR[LPDOEURQFKLHFWDVLV
5HFXUUHQWVHJPHQWDORU
OREDUFROODSVHDVVRFLDWHG
ZLWK$VSHUJLOOXVSOXJVDQG
EURQFKLDOGDPDJH
)XQJXVEDOOLQDFDYLW\
IRUPHGE\ROG7%RU
F\VWLFGLVHDVHRUPD\EH
VSRQWDQHRXV
,PPXQRFRPSURPLVHGSDWLHQW
3RRUSURJQRVLV
)OHHWLQJOXQJVKDGRZV
(RVLQRSKLOLD
Fig. 28.42  Diseases caused by Aspergillus fumigatus.', 4302),
   ('2d652adc-eb03-5a8e-a609-2de7e212743d', 'KUMAR_CLARK_10_2017', 'KC-C28', 994, 1012, 0, '28
994  Respiratory disease 
The peripheral blood eosinophil count is usually raised and total 
levels of IgE are usually extremely high, at more than 1000 ng/mL 
(both that specific to Aspergillus and non-­specific). Sputum may 
show eosinophils and mycelia. Treatment is with prednisolone 
30 mg daily, which causes rapid clearing of the pulmonary infil­
trates. Antifungal agents should be used in patients on high doses 
of steroids. The asthma component responds to inhaled corticos­
teroids, although these do not influence the occurrence of pulmon­
ary infiltrates. 
Aspergilloma and invasive aspergillosis
Aspergilloma is the growth of A. fumigatus within previously dam­
aged lung tissue, where it forms a ball of mycelium within lung 
cavities. Typically, the chest X-­ray shows a round lesion with an air 
''halo'' above it. The aspergilloma itself causes little trouble, though 
occasionally massive haemoptysis may occur, requiring resection of 
the area of damaged lung containing the aspergilloma. Treatment is 
with oral antifungal agents, although invasive aspergillosis is a well-­
recognized complication of immunosuppression and often requires 
intravenous antifungal therapy. 
Drug-­ and radiation-­induced respiratory 
reactions
Drugs affecting the respiratory system are shown in Box 28.66, 
together with the types of reaction they produce. Pulmonary infil­
trates with fibrosis may result from a number of cytotoxic drugs 
used in the treatment of cancer. The most common cause of these 
reactions is bleomycin, in which case the pulmonary damage is 
dose-­related. The most sensitive test is a decrease in carbon mon­
oxide gas transfer, and therefore gas transfer should be measured 
repeatedly during treatment with the drug. The use of corticos­
teroids may help resolution.
Irradiation of the lung during radiotherapy can cause a radiation 
pneumonitis. Patients experience breathlessness and a dry cough. 
Radiation pneumonitis results in a restrictive lung defect. Corticos­
teroids should be given in the acute stage.
Further reading
Kousha M, Tadi R, Soubani AO. Pulmonary aspergillosis: a clinical review. Eur 
Resp Rev 2011; 20:156-174.
Muthiah MP, El Gamal A. Sarcoidosis. BMJ Best Practice; https://bestpractice.
bmj.com/topics/en-­gb/109.
Raghu G, Remy-­Jardin M, Myers JL et al. Diagnosis of idiopathic pulmonary 
fibrosis. An official ATS/ERS/JRS/ALAT clinical practice guideline. Am J Respir 
Crit Care Med 2018; 198:e44-e68.
Travis WD, Costabel U, Hansell DM et al. An official American Thoracic 
Society/European Respiratory Society statement: update of the international 
multidisciplinary classification of the idiopathic interstitial pneumonias. Am J 
Respir Crit Care Med 2013; 188:733-748. 
LUNG AND HEART-LUNG 
TRANSPLANTATION
Indications and donor selection
The main diseases treated by transplantation are:
 • pulmonary fibrosis
 • primary pulmonary hypertension
 • cystic fibrosis
 • bronchiectasis
 • emphysema - particularly that caused by α1-­antitrypsin inhibitor 
deficiency
 • Eisenmenger''s syndrome.
Patients selected for transplantation are usually under 60 years 
and have a life expectancy of less than 18 months, with no underly­
ing cancer and no serious systemic disease.
Organs are taken from donors under 40 years, with good car­
diac and lung function, and chest measurements slightly smaller 
than those of the recipient. Matching for ABO blood group is essen­
tial but Rhesus blood group compatibility is not necessary. Since 
donor material is limited, single-­lung transplantation is preferred 
to double-­lung or heart-lung transplantation; this can be success­
fully undertaken in pulmonary fibrosis, pulmonary hypertension and 
emphysema. Bilateral lung transplantation is needed in infective 
conditions to prevent spillover of bacteria from the diseased lung to 
a single transplanted lung. Eisenmenger''s syndrome requires heart-
lung transplant.
Immunosuppression is with ciclosporin (the inhaled formula­
tion has shown benefit) or tacrolimus, azathioprine or mycopheno­
late mofetil, and prednisolone. 
Complications and their treatment
 • Early post-­transplant pulmonary oedema requires diuretics 
and ventilatory support.
Bronchospasm
 • Penicillins, cephalosporins
 • Sulphonamides
 • Aspirin/NSAIDs
 • Monoclonal antibodies, e.g. infliximab
 • Iodine-­containing contrast media
 • β-­Adrenoceptor-­blocking drugs (e.g. propranolol)
 • Non-­depolarizing muscle relaxants
 • Intravenous thiamine
 • Adenosine 
Interstitial lung disease and/or fibrosis
 • Amiodarone
 • Anakinra (IL-­1 receptor antagonist)
 • Nitrofurantoin
 • Paraquat (weedkiller)
 • Continuous oxygen
 • Cytotoxic agents (many, particularly busulfan, CCNU, bleomycin, 
methotrexate) 
Pulmonary eosinophilia
 • Antibiotics:
 • Penicillin
 • Tetracycline
 • Sulphonamides, e.g. sulfasalazine
 • NSAIDs
 • Cytotoxic agents 
Acute lung injury
 • Paraquat 
Pulmonary hypertension
 • Fenfluramine, dexfenfluramine, phentermine 
SLE-­like syndrome including pulmonary infiltrates, effusions 
and fibrosis
 • Hydralazine
 • Procainamide
 • Isoniazid
 • Phenytoin
 • ACE inhibitors
 • Monoclonal antibodies
   
ACE, angiotensin-­converting enzyme; CCNU, chloroethyl-­cyclohexyl-­nitrosourea 
(lomustine); IL-­1, interleukin 1; NSAIDs, non-­steroidal anti-­inflammatory drugs; SLE, 
systemic lupus erythematosus.
Box 28.66 Some drug-­induced respiratory reactions', 5441),
   ('a20df52d-5cea-588e-b701-e7da7e079959', 'KUMAR_CLARK_10_2017', 'KC-C28', 995, 1013, 0, '28
Occupational Lung Disease  995
 • Infections are common, particularly within the first 3 months, 
and need prompt treatment:
 
• bacterial pneumonia - antibiotics
 
• cytomegalovirus infection - ganciclovir or valganciclovir (often 
given as prophylaxis in the early post-­transplantation period)
 
• herpes simplex virus - aciclovir
 
• Pneumocystis jirovecii - co-­trimoxazole (often given as 
prophylaxis).
 • Rejection:
 
• Early (first few weeks) - high-­dose intravenous corticos­
teroids.
 
• Late (after 3 months) - often produces the histological pattern 
of obliterative bronchiolitis. High-­dose intravenous corticos­
teroids are sometimes effective in obliterative bronchiolitis.
 • Post-­transplant lymphoproliferative disease refers to a range 
of lymphomas seen in recipients of solid organ transplants; they 
may respond to rituximab, an anti-­B-­cell monoclonal antibody, 
or other forms of chemotherapy. 
Prognosis
Several studies show a major improvement in overall quality of life 
after transplantation. One-­year survival rates are around 80%, with 
a yearly mortality rate thereafter of about 10%. Death is due mainly 
to obliterative bronchiolitis. Overall survival varies with the original 
diagnosis but median survival is approximately 4 years. 
OCCUPATIONAL LUNG DISEASE
Exposure to dusts, gases, vapours and fumes at work can cause 
several different types of lung disease:
 • acute bronchitis and even pulmonary oedema from irritants 
such as sulphur dioxide, chlorine, ammonia or the oxides of 
­nitrogen
 • pulmonary fibrosis caused by mineral dust
 • occupational asthma (see Box 28.18), now the most common 
industrial lung disease in the developed world
 • hypersensitivity pneumonitis (see Box 28.64)
 • bronchial carcinoma due to industrial agents (e.g. asbestos, 
polycyclic hydrocarbons, radon in mines).
The degree of fibrosis that follows inhalation of mineral dust var­
ies. While iron (siderosis), barium (baritosis) and tin (stannosis) lead 
to dramatic, dense, nodular shadowing on the chest X-­ray, their 
effect on lung function and symptoms is minimal. In contrast, expo­
sure to silica or asbestos leads to extensive fibrosis and disability. 
Coal dust has an intermediate fibrogenic effect and used to account 
for 90% of all compensated industrial lung diseases in the UK.
Box 28.67 outlines how to take an occupational history in lung 
disease.
Coal-­worker''s pneumoconiosis
This disease is caused by coal dust particles approximately 2-5 μm 
in diameter that are retained in the small airways and alveoli of the 
lung. The incidence is related to total dust exposure, which is high­
est at the coal face, particularly if ventilation and dust suppression 
are poor. Improved ventilation and working conditions have reduced 
the risk of this disease.
Two very different syndromes result from the inhalation of coal.
Simple pneumoconiosis
This simply reflects the deposition of coal dust in the lung, which 
produces fine micronodular shadowing on the chest X-­ray. It is 
graded on the chest X-­ray appearance according to standard cat­
egories set by the International Labour Office:
 • Category 1: small round opacities definitely present but few in 
number
 • Category 2: numerous small round opacities but normal lung 
markings still visible
 • Category 3: very numerous small round opacities and normal 
lung markings partly or totally obscured.
There is considerable dispute about the effects of simple pneu­
moconiosis on respiratory function and symptoms. In many cases, 
symptoms may be due to COPD related to coexisting cigarette 
smoking but this is not always the case. Changes to UK workers'' 
compensation legislation means that coal miners who develop 
COPD are compensated for their disability, regardless of their chest 
X-­ray appearance.
Simple pneumoconiosis can progress to the development of 
progressive massive fibrosis (see next section). The latter virtually 
never occurs on a background of category 1 simple pneumoco­
niosis but does arise in about 7% of those with category 2 disease 
and in 30% of those with category 3 disease. Miners with category 
1 pneumoconiosis are unlikely to receive compensation unless they 
also have evidence of COPD. Those with more extensive radio­
graphic changes are compensated solely on the basis of their X-­ray 
appearances. 
Progressive massive fibrosis
In progressive massive fibrosis (PMF), patients develop round, 
fibrotic masses several centimetres in diameter, almost invariably 
situated in the upper lobes and sometimes having necrotic central 
cavities. Rheumatoid factor and antinuclear antibodies are both 
often present in the serum of patients with PMF, and also in those 
suffering from asbestosis or silicosis. Pathologically, there is apical 
destruction and disruption of the lung, resulting in emphysema and 
airway damage. Lung function tests show a mixed restrictive and 
obstructive ventilatory defect with loss of lung volume, irreversible 
airflow limitation and reduced gas transfer.
The patient with PMF suffers considerable effort dyspnoea, usu­
ally with a cough. The sputum may be black. The disease can prog­
ress (or even develop) after exposure to coal dust has ceased and 
may lead to respiratory failure. 
Silicosis
Silicosis is caused by the inhalation of silica (silicon dioxide). 
While uncommon, it may still be encountered in stonemasons, 
sand-­blasters, pottery and ceramic workers, and foundry workers 
involved in fettling (removing sand from metal castings made in 
 • Proceed chronologically. Most people cannot randomly remember, for 
example, what they might have been doing 20 years ago, or indeed, if 
asked in isolation, when they worked in a particular job. But if you start 
at the beginning of their life and work forward they find it much easier to 
remember (try it on yourself, starting with school examinations).
 • Start by asking the patient how old they were when they left school, and 
what job or further education they went to; then ask them to continue 
through their life to the present day.
 • Particularly for those who went on to further education, ask about holiday 
jobs (you might be surprised at their responses) and if they travelled 
overseas with their employment, especially if they were in the armed 
forces.
 • Do not assume that all 80-­year-­olds are retired or that all young patients 
are in employment.
Box 28.67 Taking an occupational history', 6467),
   ('07c9218f-217b-584d-9fc6-106e7121ab19', 'KUMAR_CLARK_10_2017', 'KC-C28', 996, 1014, 0, '28
996  Respiratory disease 
sand-­filled moulds). The dust is highly fibrogenic; a coal miner can 
remain healthy with 30 g of coal dust in the lungs but 3 g of silica is 
sufficient to kill. Silica seems particularly toxic to alveolar macro­
phages and readily initiates fibrogenesis. The chest X-­ray appear­
ances and clinical features of silicosis are similar to those of PMF 
but distinctive thin streaks of calcification may be seen around the 
hilar lymph nodes (''eggshell'' calcification). 
Diseases caused by asbestos
Asbestos is a mixture of silicates of iron, magnesium, nickel, cad­
mium and aluminium, and has the unique property of occurring 
naturally as a fibre. It is remarkably resistant to heat, acid and alkali, 
and has been widely used for roofing, insulation and fireproofing. 
Asbestos has been mined in southern Africa, Canada, Australia 
and Eastern Europe. Several different types of asbestos are rec­
ognized: about 90% of asbestos is chrysotile, 6% crocidolite and 
4% amosite.
Chrysotile (white asbestos) is the softest asbestos fibre. Each 
fibre is often as long as 2 cm but only a few microns thick. It is less 
fibrogenic than crocidolite.
Crocidolite (blue asbestos) is particularly resistant to chemical 
destruction and exists in straight fibres up to 50 cm in length and 
1-2 μm in width. Crocidolite is the type of asbestos most likely to 
produce asbestosis and mesothelioma.
Amosite (brown asbestos) was used in cement and pipe insu­
lation and has sharp, needle-­like fibres; exposure creates a higher 
risk of cancer in comparison with common chrysotile asbestos.
Exposure to asbestos occurred particularly in shipbuilding yards 
and in power stations, but it was used so widely that low levels 
of exposure were very common. There is a considerable time lag 
between exposure and development of disease, particularly meso­
thelioma (20-40 years). Regulations in the UK now prohibit the use 
of crocidolite and severely restrict the use of chrysotile. Careful dust 
control measures are enforced, which should eventually abolish the 
problem.
The risk of primary lung cancer (usually adenocarcinoma) is 
increased in people exposed to asbestos, even non-­smokers. 
This risk is about 5-7-­fold greater in those who have parenchymal 
asbestosis and about 1.5-­fold in those with pleural plaques with­
out parenchymal fibrosis. A synergistic relationship exists between 
asbestosis and cigarette smoking, the risk of bronchial carcinoma 
being about fivefold the risk attributable to smoking alone.
Diseases caused by asbestos are summarized in Box 28.68. 
Bilateral diffuse pleural thickening, asbestosis, mesothelioma (see 
p. 980) and asbestos-­related carcinoma of the bronchus are all eli­
gible for industrial injuries benefit in the UK.
Asbestosis
Asbestosis is defined as fibrosis of the lungs caused by asbestos dust, 
which may or may not be associated with fibrosis of the parietal or 
visceral layers of the pleura. It is a progressive disease characterized 
by breathlessness and accompanied by finger clubbing and bilateral 
basal end-­inspiratory crackles. Minor degrees of fibrosis that are not 
seen on chest X-­ray are often revealed on HRCT scan. No treatment is 
known to alter progress, though corticos­teroids are often prescribed. 
Byssinosis
This disease is caused by cotton dust; it occurs worldwide but is 
declining rapidly in areas where the number of people employed in 
cotton mills is falling. Typically, symptoms start on the first day back 
at work after a break (Monday sickness), with improvement as the 
week progresses. Tightness in the chest, cough and breathlessness 
occur within the first hour in dusty areas of the mill.
The exact nature of the disease and its aetiology remain dis­
puted. Pure cotton does not cause the disease, and cotton dust 
has some effect on airflow limitation in all those exposed. Individu­
als with asthma are particularly badly affected by exposure to cot­
ton dust. The most likely aetiology is constriction of the airways of 
the lung caused by endotoxins from bacteria present in raw cotton. 
There are no changes on the chest X-­ray. 
Effect
Exposure
Chest X-­ray
Lung function
Symptoms
Outcome
Asbestos bodies
Light
Normal
Normal
None
Evidence of asbestos 
exposure only
Pleural plaques
Light
Pleural thickening 
(parietal pleura) and 
calcification (also in 
diaphragmatic pleura)
Mild restrictive 
ventilatory defect
Rare, occasional mild 
effort dyspnoea
No other sequelae
Effusion
First two decades 
following exposure
Effusion
Restrictive
Pleuritic pain, 
dyspnoea
Often recurrent
Bilateral diffuse 
pleural thickening
Light/moderate
Bilateral diffuse thicken­
ing (of both parietal 
and visceral pleura) 
>5 mm thick and 
extending over more 
than ¼ of chest wall
Restrictive 
ventilatory defect
Effort dyspnoea
May progress in 
absence of further 
exposure
Mesothelioma
Light (interval of 
20-40 years from 
exposure to disease)
Pleural effusion, usually 
unilateral
Restrictive 
ventilatory defect
Pleuritic pain, 
increasing dyspnoea
Median survival 
2 years
Asbestosis
Heavy (interval of 
5-10 years from 
exposure to disease)
Diffuse bilateral streaky 
shadows, honeycomb 
lung
Severe restrictive 
ventilatory defect 
and reduced gas 
transfer
Progressive dyspnoea
Poor, progression in 
some cases after 
exposure
Asbestos-­related 
carcinoma of the 
bronchus
The features of asbestosis, bilateral diffuse pleural thickening or bilateral pleural plaques plus those of 
bronchial carcinoma
Fatal
Box 28.68 Effects of asbestos on the lung', 5564),
   ('a69b0088-e66e-5dc4-92d7-411508a78407', 'KUMAR_CLARK_10_2017', 'KC-C28', 997, 1015, 0, '28
Disorders of the Diaphragm  997
Berylliosis
Beryllium-copper alloy has a high tensile strength and is resistant to 
metal fatigue, high temperature and corrosion. It is used in the aero­
space industry, atomic reactors and many electrical devices. When 
beryllium is inhaled, it can cause a systemic illness with a clinical 
picture similar to that of sarcoidosis. Clinically, there is progressive 
dyspnoea with pulmonary fibrosis. However, strict control of levels 
in the working atmosphere has made this disease a rarity.
Further reading
Cullinan P, Muñoz X, Suojalehto H et al. Occupational lung disease: from old 
and novel exposures to effective preventive strategies. Lancet Respir Med 2017; 
5:445-455.
European Respiratory Society. Occupational Lung Disease; 
https://www.erswhitebook.org. 
MISCELLANEOUS RESPIRATORY 
DISORDERS
Lung cysts
These can be congenital, bronchogenic or the result of a seques­
trated pulmonary segment. Lung cysts therefore have a wide dif­
ferential diagnosis, informed by the clinical presentation. Causes 
include:
 • hydatid disease, which causes fluid-­filled cysts
 • lung abscesses (thin-­walled cysts, found particularly in staphy­
lococcal pneumonia)
 • cavitating tuberculosis
 • septic pulmonary infarction
 • primary bronchogenic carcinoma or cavitating metastatic neo­
plasms
 • paragonimiasis caused by the lung fluke Paragonimus westermani
 • systemic conditions such as Birt-Hogg-Dubé syndrome. 
Trauma
Trauma to the thoracic wall can cause penetrating wounds and lead 
to pneumothorax or haemothorax.
Rib fractures
Rib fractures are caused by trauma or coughing (particularly in the 
elderly), and can occur in patients with osteoporosis. Pathological 
rib fractures are due to metastatic spread (most often from carci­
noma of the bronchus, breast, kidney, prostate or thyroid). Ribs 
can also become involved by a mesothelioma. Fractures may not 
be readily visible on a postero-­anterior chest X-­ray and so lateral 
X-­rays and oblique views may be necessary.
Pain prevents adequate chest expansion and coughing, and this 
can lead to pneumonia.
Treatment is with adequate oral analgesia, or by local infiltration 
or an intercostal nerve block.
Two fractures in one rib can lead to a flail segment with paradox­
ical movement: that is, part of the chest wall moves inwards during 
inspiration. This can produce inefficient ventilation and may require 
intermittent positive-­pressure ventilation, especially if several ribs 
are similarly affected. 
Rupture of the trachea or a major bronchus
Rupture of the trachea or a major bronchus can occur during decel­
eration injuries, leading to pneumothorax, surgical emphysema, 
pneumomediastinum and haemoptysis. Surgical emphysema is 
caused by air leaking into the subcutaneous connective tissue; 
this can also arise after insertion of an intercostal drainage tube. A 
pneumomediastinum occurs when air leaks from the lung inside the 
parietal pleura and extends along the bronchial walls. 
Rupture of the oesophagus
Rupture of the oesophagus (see p. 1170) leads to mediastinitis, usu­
ally with mixed bacterial infection. This is a serious complication 
of external injury, endoscopic procedures, bougienage or necrotic 
carcinoma, and requires broad-­spectrum antibiotics. 
Lung contusion
This causes widespread fluffy shadows on the chest X-­ray owing to 
intrapulmonary haemorrhage. It may give rise to acute respiratory 
distress syndrome (see p. 232). 
Kyphoscoliosis
Kyphoscoliosis may be congenital, due to disease of the verte­
brae such as TB or osteomalacia, or due to neuromuscular disease 
such as Friedreich''s ataxia or poliomyelitis. The respiratory effects 
of severe kyphoscoliosis are often more pronounced than might 
be expected and respiratory failure and death often occur in the 
fourth or fifth decade. The abnormality should be corrected at an 
early stage if possible. Positive airway pressure ventilation delivered 
through a tightly fitting nasal mask is the treatment of choice for 
respiratory failure (see p. 229). 
Ankylosing spondylitis
Limitation of chest wall movement is often well compensated by 
diaphragmatic movement and so the respiratory effects of this dis­
ease are relatively mild (see also p. 448). It is occasionally associ­
ated with upper lobe fibrosis. 
Pectus excavatum and pectus carinatum
Pectus excavatum causes few problems other than embarrassment 
about the deep vertical furrow in the chest, which can be corrected 
surgically. The heart is seen to lie well to the left on the chest X-­ray. 
Pectus carinatum (pigeon chest) is often the result of rickets but is 
rarely seen in the West. No treatment is required. 
Pleurisy
Pleurisy is pain arising from any disease of the pleura. The local­
ized inflammation produces sharp localized pain, which is worse on 
deep inspiration, coughing and occasionally on twisting and bend­
ing movements. Common causes are pneumonia, pulmonary infarct 
and carcinoma. Rarer causes include rheumatoid arthritis and sys­
temic lupus erythematosus.
Epidemic myalgia (Bornholm disease) is caused by infection 
with Coxsackie B virus. This illness is common in young adults in 
the late summer and autumn, and is characterized by an upper 
respiratory tract illness followed by pleuritic pain in the chest and 
upper abdomen with tender muscles. The chest X-­ray remains nor­
mal and the illness clears within a week. 
DISORDERS OF THE DIAPHRAGM
Diaphragmatic fatigue
The diaphragm can become fatigued if the force of contraction dur­
ing inspiration exceeds 40% of the force it can develop in a maximal', 5610),
   ('9ce08659-a418-5de4-9d1b-a0f8baaef440', 'KUMAR_CLARK_10_2017', 'KC-C28', 998, 1016, 0, '28
998  Respiratory disease 
static effort. When this occurs acutely, in patients with exacerbations 
of COPD or cystic fibrosis, or in quadriplegics, positive-­pressure 
ventilation is required. Further rehabilitation requires exercises to 
increase the strength and endurance of the diaphragm by breathing 
against resistance for 30 minutes a day. 
Unilateral diaphragmatic paralysis
This is common and symptomless. The affected diaphragm is usu­
ally elevated and moves paradoxically on inspiration. It can be diag­
nosed by ultrasound when a sniff causes the paralysed diaphragm 
to rise and the unaffected diaphragm to descend. Causes include:
 • surgery
 • carcinoma of the bronchus with involvement of the phrenic nerve
 • neurological disease, including poliomyelitis and herpes zoster
 • trauma to the cervical spine, birth injury or subclavian vein punc­
ture
 • infection, such as TB, syphilis or pneumonia. 
Bilateral diaphragmatic weakness or 
paralysis
This causes breathlessness in the supine position and may lead 
to sleep apnoea, with daytime headaches and somnolence. Tidal 
volume is decreased and respiratory rate increased. Vital capac­
ity is substantially reduced when lying down and sniffing causes a 
paradoxical inward movement of the abdominal wall, best seen in 
the supine position. Causes include viral infections, multiple sclero­
sis, motor neurone disease, poliomyelitis, Guillain-Barré syndrome, 
quadriplegia after trauma, and rare muscle diseases. Treatment is 
either diaphragmatic pacing or night-­time assisted ventilation. 
Complete eventration of the diaphragm
This is a congenital condition (invariably left-­sided) in which muscle 
is replaced by fibrous tissue. It presents as marked elevation of the 
left hemidiaphragm, sometimes associated with gastrointestinal 
symptoms. Partial eventration, usually on the right, causes a hump 
(often anteriorly) on the diaphragmatic shadow on X-­ray. 
Diaphragmatic hernias
These are most commonly through the oesophageal hiatus but 
occasionally occur anteriorly, through the foramen of Morgagni, 
posterolaterally through the foramen of Bochdalek, or at any site 
following traumatic tears. 
Hiccups
Hiccups are due to involuntary diaphragmatic contractions with 
closure of the glottis and are extremely common. Occasionally, 
patients present with persistent hiccups. This can be as a result 
of diaphragmatic irritation (e.g. subphrenic abscess) or may have a 
metabolic cause (e.g. uraemia). Treatment for persistent hiccups is 
with gabapentin 300 mg or pregabalin 50 mg three times daily. The 
underlying cause should be treated, if known.
Further reading
McCool ED, Tzelepis GE. Dysfunction of the diaphragm. N Engl J Med 2012; 
366:932-942. 
MEDIASTINAL LESIONS
The mediastinum is defined as the region between the pleural 
sacs. It is additionally divided as shown in Fig. 28.43. Tumours 
affecting the mediastinum are rare. Masses are detected very 
accurately on CT, as well as on MRI scan (Fig. 28.44), and can 
be localized to the anterior, middle or posterior mediastinum. The 
position and characteristics of the lesion will help to determine the 
underlying aetiology.
Anterior mediastinum
Retrosternal or intrathoracic thyroid
The most common mediastinal mass is a retrosternal or intrathor­
acic thyroid, which is nearly always an extension of the thyroid 
present in the neck. Enlargement of the thyroid by a colloid goitre 
or malignant disease, or, rarely, in thyrotoxicosis, can cause dis­
placement of the trachea and oesophagus to the opposite side. 
Symptoms of compression develop insidiously before producing 
the cardinal feature of dyspnoea. Flow-volume loops are useful to 
assess the physiological impact. Very occasionally, an intrathoracic 
+LOXP
2HVRSKDJXV
$RUWD
&DUFLQRPDRIWKHEURQFKXV
3XOPRQDU\K\SHUWHQVLRQ
/DUJHSXOPRQDU\DUWHULHV
6DUFRLG
/\PSKRPD
7XEHUFXORVLV
%URQFKRJHQLFF\VWV
6XSHULRU
PHGLDVWLQXP
5HWURVWHUQDOWK\URLG
7K\PLFWXPRXUV
$RUWLFDQHXU\VPV
''HUPRLGF\VWV
/\PSKRPD
2HVRSKDJHDOF\VWV
$QWHULRU
PHGLDVWLQXP
''HUPRLGF\VWV
7K\PLFWXPRXUV
+HUQLDWKURXJK
IRUDPHQRI
0RUJDJQL
0LGGOH
PHGLDVWLQXP
3OHXURSHULFDUGLDOF\VWV
/LSRPD
&DUGLDFWXPRXUV
3RVWHULRU
PHGLDVWLQXP
1HXURJHQLFWXPRXUV
$RUWLFDQHXU\VPV
+LDWXVKHUQLD
3DUDYHUWHEUDODEVFHVVHV
Fig. 28.43  Subdivisions of the mediastinum and mass 
lesions.
Fig. 28.44  CT scan of a dermoid cyst (arrowed) in the 
mediastinum.', 4410),
   ('74f59f29-7339-56f2-baff-6997fbf768c5', 'KUMAR_CLARK_10_2017', 'KC-C28', 999, 1017, 0, '28
Mediastinal Lesions  999
thyroid may cause dysphagia or hoarseness and vocal cord paraly­
sis due to stretching of the recurrent laryngeal nerve. The treatment 
is surgical removal. 
Thymic tumours (thymomas)
The thymus is large in childhood and occupies the superior and 
anterior mediastinum. It involutes with age but may be enlarged 
by cysts, which are rarely symptomatic, or by tumours, which may 
cause myasthenia gravis or compress the trachea or, rarely, the 
oesophagus. Surgery is the treatment of choice. Approximately half 
of the patients presenting with a thymic tumour have myasthenia 
gravis. Good''s syndrome, a combined defect of humoral and cel­
lular immunity, is seen in 10% of thymomas. 
Middle mediastinum
 • Bronchogenic cyst is a benign growth that is an embryological 
remnant.
 • Mediastinal lymphadenopathy may be due to a number of con­
ditions, including metastatic lesions, primary lung cancer, sar­
coid, and infection such as tuberculosis. Lymphoma commonly 
presents with enlargement of the middle mediastinal nodes, and 
may represent both Hodgkin or non-­Hodgkin disease (see pp. 
399 and 401).
 • Pericardial cysts, which may be up to 10 cm in diameter, are 
filled with clear fluid. Some 70% of them are situated anter­
iorly in the cardiophrenic angle on the right side. Infection is 
rare and malignant change does not occur. The diagnosis 
may be made on MRI but needle aspiration may be required 
if there is any diagnostic uncertainty. No treatment is required 
but patients should be followed up, as an increase in cyst 
size suggests an alternative pathology and surgical excision 
is then advisable.
 • Vascular abnormalities include aortic aneurysm and aortic 
­dissection.
 • Tracheal tumours were discussed earlier. 
Posterior mediastinum
 • Embryological remnants include neurogenic and neuroenteric 
cysts.
 • Oesophageal abnormalities, e.g. oesophageal tumours and 
hiatus hernias, are seen here.
Significant websites
http://www.asthma.org.uk Asthma UK.
http://www.brit-­thoracic.org.uk British Thoracic Society.
http://www.nhs.uk/live-well/quit-smoking Good site for those wanting to stop 
smoking or to help patients to stop.
http://www.thoracic.org American Thoracic Society.', 2240)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- extraction_job
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.extraction_job (extraction_id, source_version_id, chapter_id, extraction_type, status) VALUES
   ('EXT-KC28', 'KUMAR_CLARK_10_2017', 'KC-C28', 'RESPIRATORY_METHOD', 'PENDING')
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source (source_id, source_name, edition, year, source_type, authority_scope, amexan_role, description, publisher, language_code, status) VALUES
   ('NELSON_ILLUSTRATED', 'Illustrated Baby Nelson', 1, 2017, 'textbook', 'paediatrics', 'INTERPRET + MANAGE (PAEDIATRIC)', 'Illustrated paediatric revision text (Dr Mohamed El Koumi, 2017-2020); the Pulmonology chapter forms the paediatric overlay of the respiratory vertical slice.', 'University Book Center', 'en', 'ACTIVE_FOUNDATION')
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_version
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_version (version_id, source_id, edition, publication_year, language, supersedes, effective_from, status, pdf_page_offset, page_count, file_path) VALUES
   ('NELSON_ILLUSTRATED_2017', 'NELSON_ILLUSTRATED', 1, 2017, 'English', NULL, '2017-01-01', 'ACTIVE', 13, 692, 'C:\Users\Administrator\Desktop\UPLOADS\Baby Nelson   2017 - 2020.pdf')
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_section
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_section (section_id, source_version_id, section_no, section_name, amexan_layer, sort_order) VALUES
   ('BN-S1', 'NELSON_ILLUSTRATED_2017', 1, 'Pulmonology', 'SYSTEM', 1)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_chapter
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_chapter (chapter_id, source_version_id, section_id, chapter_no, chapter_name, start_page, end_page, amexan_role, amexan_context, amexan_system, sort_order) VALUES
   ('BN-C01', 'NELSON_ILLUSTRATED_2017', 'BN-S1', 1, 'Pulmonology', 156, 213, 'INTERPRET + MANAGE (PAEDIATRIC)', 'PAEDIATRIC', 'RESPIRATORY', 1)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- source_chunk  (page-anchored raw text, printed page numbers)
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.source_chunk (id, source_version_id, chapter_id, page_number, pdf_page_index, chunk_index, chunk_text, char_count) VALUES
   ('41288526-06a7-5514-b85c-3f88b90c6104', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 156, 169, 0, 'Page | 2 Illustrated Baby Nelson 
156
 
 
 
Acute Pharyngitis 
It include acute tonsillitis, pharyngitis or tonsillopharyngitis 
Causes 
Viral or Bacterial (group A E hemolytic streptococci is the commonest.). 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
Complications 
 As that of scarlet fever + 
 Mesenteric adenitis (o abdominal pain). 
Treatment 
* Symptomatic for fever. 
* Specific: e.g. 10 days course of antibiotic (5 days for Zithromax) 
 Penicillin V 
 Amoxicillin 
 Cephalosporins 
 Zithromax 
 Clarithromycin 
 * Surgical: 
 A tonsillectomy, with or without adenoidectomy 
 Indications: 
1. The most common indication for adenotonsillectomy is adenotonsillar 
hypertrophy associated with obstructive sleep apnea 
2. Recurrent tonsillitis defined as : 
 Seven or more documented infections in 1 year 
 Five per year for 2 years 
 Or three per year for 3 years 
3. Recurrent peritonsillar abscess 
4. Multiple antibiotic allergies. 
Complaint 
 Fever, anorexia 
and malaise 
 Sore throat 
 Dysphagia 
 Red , congested throat 
 Inflamed tonsils with 
white or yellow exudates 
 Enlarged tender lymph 
nodes on the front of the 
neck 
 Associations 
 Conjunctivitis (Adeno 
virus) 
 Minute vesicles and 
ulcers (Coxachie virus) 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1333),
   ('d0290540-d77d-50f3-a9d7-a02660104be1', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 157, 170, 0, 'Page | 3 
 Illustrated Baby Nelson 
157
 
Otitis Externa 
 "Swimmer''s ear" 
 Cellulitis of the soft tissues of the external auditory canal 
 Risk factors : trauma ,humidity, heat, and moisture in the ear 
 
 
 
 
 
 
 
 
 
 
Essentials to diagnosis 
 Edema and erythema of the external auditory canal with debris or thick, 
purulent discharge. 
 Severe ear pain, worsened by manipulation of the pinna. 
 Periauricular and cervical lymphadenopathy may be present 
 
 
 
 
 
 
 
 
 
 
 
 
Management 
 Pain control 
 Removal of debris from the canal 
 Topical antimicrobial therapy, Fluoroquinolone eardrops are the first-line 
 Avoidance of causative factors 
 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 759),
   ('48b3d451-4af1-5485-8e27-0358cb06e96b', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 158, 171, 0, 'Page | 2 Illustrated Baby Nelson 
158
 
 
 
Acute Otitis Media ( AOM) 
Risk factors 
Eustachian tube obstruction by adenoids or edema in upper respiratory infection 
Others:Impaired host immune defenses, bottle feeding, genetic susceptibility 
Causes 
1. Viral; AOM is a known complication of bronchiolitis 
2. Bacterial: mainly H. influenza , pneumococci, moraxilla catarrhalis 
Clinical picture 
 Fever 
 Earache (irritability , rubbing the ears in infants) 
 Otoscopic examination: 
 Drum is congested, bulging 
 Middle ear effusion 
 Drum may be perforated ± discharge. 
 
 
 
 
 
 
Acute OM 
Severe acute OM 
Draining acute OM 
Resolving acute OM 
 Complications: 
 Mastioditis: tender swelling behind the ear 
 Chronic ear infection: draining ears for 14 days or more 
Treatment 
* Symptomatic for pain & fever: ibuprofen or acetaminophen 
* Specific 
 Antibiotic or observation? 
 For infants younger than 6 monthsĺ antibiotics are always 
recommended on the first visit, regardless of diagnostic certainty 
 For children \HDUVZLWKXQFRPSOLFDWHGRWLWLVPHGLDZLWKRXW
otorrheaĺ optional 48 hours of observation 
 Antibiotics 
 Amoxicillin-clavulanate enhanced strength ;ES (14:1 ratio of 
amoxicillin: clavulanate), with amoxicillin dose 90 mg/kg/d for 10 days 
 Alternatives: Ceftriaxone (injections for 3 days), Cefdinir, or 
Cefpodoxime ĺThen, according to culture and sensitivity 
 Surgical :Tympanocentesis & drainage ± Tympanostomy tubes 
 Patients with tympanostomy tubes with acute otorrhea ĺototopical 
antibiotics (fluoroquinolone eardrops) are first-line therapy 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1695),
   ('fbb6ebd7-dfd2-5d43-a5d7-737963987abf', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 159, 172, 0, 'Page | 3 
 Illustrated Baby Nelson 
159
 
Acute Sinusitis 
 The maxillary and ethmoid sinuses are most commonly involved. These 
sinuses are present at birth. 
 Major risk factors: Upper respiratory tract infections and immunodeficiency 
Causes 
 As in otitis media 
 Mixed infections 
Clinical picture 
* Fever and headache 
* Purulent or mucopurulent nasal discharge & post nansal discharge cough 
* Others: 
- Nasal obstruction 
- Halitosis (fetid breath odor) 
- Diminished smell 
- Periorbital edema 
Investigations 
 Culture and sensitivity of sinus aspirate 
 Trans illumination test  opaque sinus 
 Plain X ray skull 
 CT skull 
Treatment 
 Symptomatic for pain & fever (paracetamol) 
 Specific: 
1. Antibiotics for a minimum of 10 days or 7 days after resolution of 
symptoms: 
 High dose amoxicillin or amoxicillin/clavulanate 
 Alternatives 
 Ceftriaxone 
 Cefdinir , Cefpodoxime, Cefixime, Cefuroxime 
 
Neither Zithromax nor Cotrimoxazole are recommended 
2. Saline nasal washes or nasal sprays can help to liquefy secretions and act as 
a mild vasoconstrictor 
3. The use of decongestants, antihistamines, mucolytics, and intranasal 
corticosteroids has not been adequately studied in children and is not 
recommended for the treatment of acute uncomplicated bacterial sinusitis 
 
 Surgical = Sinuscopic sinus surgery for chronic cases 
(Nelson Textbook of Pediatric)
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1489),
   ('81d08562-3f3e-5f16-ad9c-f9ec16c5f0db', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 160, 173, 0, 'Page | 2 Illustrated Baby Nelson 
160
 
 
 
 
Definition 
Harsh, continuous inspiratory sound due to variable obstruction in upper airways 
(larynx and trachea); may be associated with hoarseness of voice and respiratory 
distress 
Causes 
Acute 
 
Infectious 
Non infectious 
* Viral: 
 Laryngeotracheobronchitis 
 Acute laryngitis. 
 Spasmodic laryngitis. 
* Bacterial: 
 Acute epiglottitis. 
 Acute tracheitis (staph. aureus). 
 Diphteritic laryngitis. 
 
 Laryngeal foreign body. 
 Laryngeospasm(e.g. tetany). 
 Laryngeal edema(e.g. allergic) 
 Laryngeal compression. 
Chronic 
 
 
Congenital 
Acquired 
 Laryngeomalacia 
 Laryngeal web or cyst 
 Tracheomalacia 
 Congenital vascular ring 
 Laryngeal 
 
 Stenosis 
 Tumors 
 Paralysis 
 Tracheal stenosis 
 
 
Severity of Stridor / Croup 
 
Mild 
Moderate 
Severe 
Stridor 
± 
+ 
++ 
Sternal tug 
- 
+ 
++ 
Recession 
- 
+ 
++ 
Accessory 
muscles 
- 
+ 
++ 
Nasal flare 
- 
+ 
++ 
Cyanosis 
- 
- 
+ 
Drooling 
- 
- 
+ 
Air entry 
Normal 
Reduced 
Poor 
Hydration 
Normal 
Normal/reduced 
Reduced 
If the child does not object: 
Saturation 
Normal 
Normal/reduced 
Reduced 
Heart rate 
Normal 
Raised 
Raised (bradycardia is 
pre-terminal event) 
(Oxford Paediatric Emergency Medicine) 
Stridor
 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1357),
   ('9d1e8578-0616-5674-a6e4-ae527513171d', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 161, 174, 0, 'Page | 3 
 Illustrated Baby Nelson 
161
 
Acute Infectious Stridor
 
 Affects children 6 months - 6 years in the fall and early winter 
 Cause: Viral 
 Para-influenza types 1, 3
 Others: RSV, influenza, adenovirus, corona virus
 Presentation 
 Upper respiratory catarrh (Rhinitis, low grade fever) 
 Croupy ,barking, cough 
 Hoarseness of voice 
 Absence of drooling and toxic appearance 
 Croup severity: 
Can be severe with inspiratory and expiratory stridor and respiratory 
distress (substernal & suprasternal retractions) 
 
 
 
 
 
 
 
 
 
 
 Neck X ray 
Steeple sign: Sub glottic narrowing in antero posterior view 
 Complication : Rarely; secondary bacterLDOLQIHFWLRQĺ%DFWHULDOWUDFKHLWLV 
Differential diagnosis 

Acute laryngitis
 Less severe croup (inspiratory stridor) 
 No respiratory distress 
 Spasmodic laryngitis 
 Viral but may be allergy or psychogenic (afebrile illness) 
 Occurs at midnight 
 Less severe
 Recurrence is common

Acute epiglottitis and acute tracheitis : see later
Laryngeotracheobronchitis (Croup) 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1148),
   ('ce3b1b33-37af-5c85-94bd-91e3909e7b05', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 162, 175, 0, 'Page | 2 
 Illustrated Baby Nelson 
162
 
Management 
 Most cases respond to home treatment 
 Indication for hospitalization 
 Progressive stridor 
 Severe stridor at rest 
 Respiratory distress; hypoxia, cyanosis, depressed mental status 
 Poor oral intake 
 Mild croup (barking cough and no stridor at rest) 
 Oral hydration 
 Minimal handling 
 Mist therapy (no evidence to support its use) 
 Moderate to severe stridor at rest 
1. Oxygen for patients with oxygen desaturation 
2. Nebulized epinephrine 
 Racemic adrenaline nebulizer (0.25-0.5 ml in 3ml saline), 
 L- adernaline 5 ml 1:1000 solution is equally effective 
Value 
Reduce need for intubation for moderate to severe stridor at rest 
3. Oral corticosteroids 
 Dexamethasone: 0.6 mg/kg Oral or intramuscular as one dose. 
Lower dexamethasone dose (0.15 mg/kg) is equally effective 
 Inhaled budesonide (2-4 mg) 
Value 
Improves symptoms even in mild stridor 
Reduce need for intubation for moderate to severe stridor at rest 
 
Outcome 
 
 
 
 
(Nelson textbook of pediatrics)
Symptoms resolve within 3 
hours of glucocorticoids and 
nebulized epinephrine 

Repeat nebulized
epinephrine is required 
 Respiratory distress persists
 Hospitalization 
 Close observation
 Supportive care: secure airway,
± intubation for 2-3 days
 Discharge 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1411),
   ('0a600e79-d228-54e3-93ee-9ed867eba22c', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 163, 176, 0, 'Page | 3 
 Illustrated Baby Nelson 
163
 
 Infection of the epiglottis by Hemophilus influenza type B(in pre vaccine era) 
 Strept pyogenes, Strept pneumoniae, nontypeable H. influenzae, & Staph 
aureus, represent a larger portion of pediatric cases of epiglottitis in vaccinated 
children 
Clinical picture 
 Peak age = 2-7 years (now commoner in adults with sore throat) 
 Toxic child with high fever 
 Drooling of saliva (severe dysphagia) 
 The child is severely exhausted : 
 Voice is muffled. 
 Stridor is mild.
 Little or no cough 
 The child prefer upright posture and 
neck is hyperextended in an attempt 
to maintain the airway 
 Laryngeoscopic examination shows large 
"cherry red" swollen epiglottis but this 
procedure and any minor procedure may 
precipitate complete airway obstruction. 
Management 
Medical emergency, once suspected, the patient must be admitted to the PICU 
 Secure the Airway before any maneuver: 
 Endotracheal tube (or less often tracheostomy) is 
indicated ,regardless degree of respiratory distress , 
placed either in an operating room or ICU 
 The artificial airway is kept in place for 2-3 days
 O2 inhalation as needed 
 Blood culture and, if possible, epiglottic surface culture should be done. 
 Antibiotics: 
 Start parenteral Ceftriaxone or Cefotaxime or 
Meropenem pending result of culture & sensitivity 
 Continue antibiotics for at least 10 days. 
 Lateral X-ray of the neck if done (after securing airway) 
may show swollen epiglottis (Thumb sign) 
N.B: Household contacts < 4 years with incomplete HiB immunization or
immunocompromised require Rifampin prophylaxis (20 mg/kg orally once a day maximum 
dose 600 mg for 4 days) (Nelson textbook of pediatrics) 
Acute Epiglottitis (Supraglottitis)
 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1858),
   ('a3f584d5-54cd-5ca2-b4de-25737ebcca7d', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 164, 177, 0, 'Page | 2 Illustrated Baby Nelson 
164
 
 
 
 
 Acute bacterial infection of the upper airway that is potentially life 
threatening. 
 Staphylococcus aureus is the commonest cause 
 Often follows viral laryngotracheobronchitis 
 Commoner than acute epiglottitis basically because of introduction of Hib 
vaccine in most vaccinations protocols ¥¥ 
Clinical picture 
 The early clinical picture is similar to that of viral croup 
 Instead of gradual improvement, patients develop higher fever, toxicity, 
and progressive or intermittent severe upper airway obstruction that is 
unresponsive to standard croup therapy 
 Differentiated from epiglottitis by: 
1. Preceded by viral prodrome 
2. No posture preference; the patient can lie flat 
3. No dysphagia or drooling!! 
4. Lateral neck radiographs show a normal epiglottis but severe 
subglottic narrowing; irregular tracheal border (absent thumb sign) 
5. During endotracheal intubation/ Bronchoscopy: Normal epiglottis and 
the presence of deep red mucosa and copious purulent tracheal 
secretions below the cords confirm the diagnosis 
6. Although cultures of the tracheal secretions are frequently positive, 
blood cultures are almost always negative 
7. Despite the severity of this illness, the reported mortality rate is very 
low if it is recognized and treated promptly 
Treatment 
 Patients with suspected bacterial tracheitis will require 
 Direct visualization of the airway in a controlled environment 
 Debridement of the airway 
 Most patients will be intubated because the incidence of respiratory 
arrest or progressive respiratory failure and respiratory arrest is high 
 Thick secretions persist for several days, usually resulting in longer 
periods of intubation for bacterial tracheitis than for epiglottitis or 
croup 
 Antistaphylococcal agents: vancomycin or naficillin or oxacillin 
 Supportive care in ICU including supplemental oxygen ,suctioning 
Bacterial Tracheitis
 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 2049),
   ('a2444e9f-c2c6-5f37-b2f4-a993a01e595a', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 165, 178, 0, 'P a g e | 165  Illustrated Baby Nelson 

Lower Respiratory Diseases 
Chest Examination 
Pneumonia
Bronchopneumonia
Pleural effusion
Pneumothorax
Hydropneumothorax
Collapse
Inspection
- Movement
Decreased
Decreased bilateral
Decreased
Decreased
- Shape
Normal
Normal
Bulge
Retraction
Palpation
- Tracheal shift
Central
Central
Shifted to opposite side
To same 
side
- Tactile vocal fremitus
Increased
? Normal
Decreased
Decreased
Percussion
- Note
Impaired note
? Impaired note
Stonydull
Hyperresonance
Shifting dullness
Dull
- Topography
Lobar
Bilateral
Rising to axilla
Allover the side
Transverse upper border
Lobar
Auscultation
- Breath sounds
Diminished 
bronchial
? Normal vesicular
Markedly diminished vesicular
- Adventitious sounds
Crepitations
Bilateral wheezes ,
Crepitations
- Vocal resonance
Increased
Bronchophony 
May be normal
Decreased
Special signs
--
--
Aegophony
Coin test
Succussion splash
--
', 997),
   ('3f8f5a2d-d13f-5145-bf5a-6c404ce588d2', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 166, 179, 0, 'Page | 2 Illustrated Baby Nelson 
166
 
 
 
Pneumonia 
x Pneumonia is an infection of the lower respiratory tract that involves the 
airways and parenchyma with consolidation of the alveolar spaces 
x Pneumonitis is a general term for lung inflammation that may or may not be 
associated with consolidation 
Anatomic classification 
 Lobar pneumonia: pneumonia of one or more lobes 
 Bronchopneumonia: scattered bilateral inflammation both lungs 
 Interstitial pneumonia: bilateral perihilar pulmonary inflammation 
Etiologic classification 
Category 
Etiologic agents 
Bacterial 
 Gram-positive: e.g. Strept Pneumonae, group B and A 
streptococci ,Staphylococcus aureus 
 Gram-negative: e.g. H.influenzae , Legionella, Klebseilla 
Viral 
 Respiratory syncytial virus (RSV) parainflenza , influenza , 
adenovirus, Human metapneumovirus, Corona virus 
Atypical 
 Mycoplasma pneumoniae , Chlamydophila pneumoniae 
 Chlamydia trachomatis (in infants) 
Mycobacterial 
 Tuberculosis and atypical mycobacteria 
Aspiration 
 Oral anaerobic flora, with or without aerobes 
Allergic 
 Esinophilic pneumonia (Loffler''s syndrome) 
Rickettsial 
 Coxiella Burnetii 
Opportunistics in 
immunocompromised 
 Fungal e.g. Aspergillus , histoplasma , cryptococcus, candida 
 Protozoal ; Pneumocystis jiroveci (carinii) 
 Bacterila; Klebsiella, and proteus 
Symptoms 
 Onset is variable from acute, sub-acute or gradual 
 General 
 Fever, malaise , toxemia (worst in bronchopneumonia) 
 May be abdominal pain: Referred from lower lobe 
pneumonia 
 Chest 
 Cough (dry then productive) 
 Dyspnea and grunting 
Signs 
Respiratory distress 
 Tachypnea is the most consistent clinical manifestation of pneumonia, 
nasal flaring, retractions and grunting 
 Cyanosis and lethargy in severe infection specially in infants 
To My mother and father
To My wife and kids 
uploaded by: Dr.Maged Almansour
 
 Class 14', 1906),
   ('0cd980d1-c71d-5d28-b95f-dcad77afc0e4', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 167, 180, 0, 'Page | 3 
 Illustrated Baby Nelson 
167
 
Chest examination 
 Pneumonia ( See table previous page for pneumonia ± effusion) 

Bronchopneumonia ( See table previous page) 

Interstitial pneumonia:o Minimal chest findings. 
o Prolonged expiration & wheezes are common
Viral or bacterial pneumonia? 
1. Clinical 
Large pleural effusion, lobar consolidation, and a high fever at the onset of 
the illness are suggestive of a bacterial etiology 
2. Investigations : See later
 
Investigations 
 
A. Radiological 
1. Chest X-ray findings: 
A. Lobar pneumonia
 Homogenous opacity in one or more lobes
 With clear costopherinic angle (differentiate it from effusion)
 Usually bacterial 
 
 
 
 
 
 
Right sided middle lobe 
pneumonia 
Left sided lower lobe 
pneumonia 
Right sided upper lobe 
pneumonia 
 
B. Bronchopneumonia 
 Scattered opacities in both lungs 
 Viral or bacterial 
 
 
 
 
C. Interstitial pneumonia 
 Scattered bilateral interstitial infiltrates and peribronchial cuffing 
 Hyperinflation, and atelectasis
 Seen in viral bronchopneumonia and atypical pneumonia
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1169),
   ('97456f97-6e14-524a-8706-06a86ea35125', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 168, 181, 0, 'Page | 2 
 Illustrated Baby Nelson 
168
D. Complications 
Effusion, abscess, or pneumatoceles (single or multiple, thin-walled, 
air-filled, cystlike cavities) may indicate S. aureus, gram-negative, or 
complicated pneumococcal pneumonia. 
 
 
Meningitis, suppurative arthritis, and osteomyelitis are rare complications 
of hematologic spread of pneumococcal or H. influenzae type b infection 
2. Ultrasonography: 
 Highly sensitive and specific in diagnosing 
pneumonia by determining lung 
consolidations and air bronchograms or 
effusions 
 Differentiate simple effusion and empyema 
 Guide thoracentesis of a loculated effusion 
3. Contrast CT scan, CT or ultrasonography guided lung biopsy: 
Reserved for complicated cases/ rare pneumonias 
B. Laboratory 
1- WBC count 
 In viral pneumonia usually not higher than 20,000/mm3, with a 
lymphocyte predominance 
 In bacterial pneumonia, in the range of 15,000-40,000/mm3, and a
predominance of granulocytes 
 Mild eosinophilia is characteristic of infant C. trachomatis pneumonia 
2- Acute phase reactants: High ESR, positive C-reactive protein and
Procalcitonin usually suggest bacterial rather than viral pneumonia 
3- Isolation of an organism 
Indicated for 
 Ill cases that require hospitalization
 Immunocompromised patients
 Patients with recurrent pneumonia
 Pneumonia unresponsive to empirical therapy 
 Effusion (Left) 
 Lung abscess (Right) 
 Pneumatoceles (Right) 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1524),
   ('530c0ef1-546d-5473-a64f-47c59e866589', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 169, 182, 0, 'Page | 3 
 Illustrated Baby Nelson 
169
Workup 
 Blood cultures are positive in 10% to 20% of bacterial pneumonia
 Pleural fluid culture
 Lung tracheobronchial secretions culture 
 Invasive: Bronchoscopy with bronchoalveolar lavage ,brush 
mucosal biopsy, needle aspiration of the lung, and open lung biopsy 
 Specific testing e.g.
 M. tuberculosis : tuberculin skin test, serum interferon-gamma
release assay, or analysis of sputum or gastric aspirates by 
culture, antigen detection, or PCR 
 Detect the virus or viral antigens by DNA or RNA tests 
4- Serology: for rising antibody titers: 
- Cold agglutinins in 50% of mycoplasma pneumonia (non specific test).
- ASO titer in streptococcal pneumonia 
Complications 
Respiratory 
Systemic 
 Pleural effusion 
 Empyema with or without 
bronchopleural fistula and 
pyopneumothorax 
 Lung abscess
 Pneumatoceles 
 Unresolved pneumonia 
These complications are more common 
with Staph and Klebseilla pneumonia 
 Meningismus especially with right
upper lobe pneumococcal pneumonia 
 Heart failure 
 Distant infections e.g. Septicemia,
meningitis, pericarditis 

Paralytic ileus
Differential Diagnosis of pneumonia
1. Viral pneumonia 
The commonest cause in pre-school children with peak at 2- 3 years 
Causes: RSV, parainfluenza (1, 2, and 3) viruses, influenza (A and B) 
viruses, human metapneumovirus, and adenovirus 
Clinically: - Preceding upper respiratory tract infection for several days. 
- Fever & respiratory distress  milder than bacterial pneumonia. 
- May be widespread wheezes and crepitations. 
Diagnosis 
 CXR: Bilateral peri hilar infiltrates (bronchopneumonia or interstitial
pneumonia) ± Hyperinflation. 
Pleural effusions, pneumatoceles, abscesses, lobar consolidation, and 
"round" pneumonias are generally inconsistent with viral disease 
 CBC : normal or mildly elevated WBCs with predominant lymphocytes 
 Detect the virus or viral antigens by DNA or RNA tests 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 2040),
   ('4244de1e-0029-56d7-9ae0-b99e2ca17901', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 170, 183, 0, 'P a g e | 170 
 Illustrated Baby Nelson 
2. Bacterial pneumonia
Pneumococcal*
Streptococcal
Staphylococcal
H. Influenzae*
Klebsiella
Age
Commonest bacterial. 
pneumonia in 
children
Peak age 3-5 yr.
Peak age below 1 year
History : staph skin 
infection
Peak age below 3 
yr
more in immune 
deficient
- Has high mortality
C/P
- Moderate
- Moderate fever
- Usually lobar
- Bronchopneumia is
commoner in young
infants
- Severe with extreme
prostration
- High fever
- Bronchopneumonia
with large pleural
effusion
- Severe
- High fever
- May be
bronchopneumonia
or lobar or hemithorax
- Complications
(abscess, empyema ,
pneumatoceles, and
pneumothorax)
- Insidious onset
- Prolonged
course over
weeks
- Usually lobar;
involving two
or more lobes
- Severe , fulminant
- High fever with
copious purulent
secretions
- Usually lobar
- Complications as
Staph.
* High incidence of penicillin resistance so treat with high doses of amoxicillin (80-90 mg/kg/24 hr) or cefuroxime or 3rd generation cephalosporin
3. Mycoplasma pneumonia (Primary Atypical Pneumonia): Common in school age (5-15 yr)
Clinically 
 Severe nonproductive cough without significant respiratory distress
 Pharyngitis is common
 Minimal physical signs (walking pneumonia)
 May be chest wheezes and inspiratory crepitations
Diagnosis is mainly clinical. 
 Blood: CBC is usually normal, Cold agglutinins may be detected
 Chest X-ray show:
 Scattered bilarteral perihilar pulmonary infiltrates
 Rarely: Lobar pneumonia ± effusion.', 1495),
   ('c8d48b5f-e21c-5f8c-9e0f-cd4d4f0defb6', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 171, 184, 0, 'Page | 3 
 Illustrated Baby Nelson 
171
 
Treatment of pneumonia 
i. Supportive 
 
 Bed rest, humidified O2 inhalation ± restricted I.V. fluids 
 Symptomatic treatment e.g. antipyretics for fever 
 Treatment of complications e.g. Heart failure. 
 Aspiration /drainage for effusion or empyema 
 Oral zinc (10- 20 mg/day) is recommended add-on in developing countries 
ii. Specific treatment 
 
1. Suspected bacterial pneumonia: Antibiotics 
 As suggested by clinical picture & chest X-ray 
 Based on the presumptive cause and the age 
 Antibiotic combination if the cause cannot be detected 
Duration: For 10-14 days, 5 days if azithromycin is used 
Empirical therapy 
Milder cases 
 Amoxicillin (50-90 mg/kg/dose) or Cefuroxime 
or Amoxicillin clavulanate 
Hospitalized cases 
 Children less than 4 weeks 
 IV Ampicillin and an Aminoglycoside 
 Infants 4-12 weeks of age 
 IV Ampicillin for 7-10 days 
 Older child fully immunized 
against H. influenzae type B 
and S. pneumoniae 
 
Yes 
ĺAmpicillin or penicillin G. 
 No 
ĺParenteral cefotaxime or ceftriaxone 
 Suspected Staph 
 Add vancomycin or clindamycin 
 Suspected Klebsiella 
 Add aminoglycoside 
 Mycoplasma pneumonia 
 Erythromycin or azithromycin or clarithromycin 
 In adolescents 
 Fluoroquinolones may be considered 
(Nelson textbook of Pediatrics, 2016) 
2. Viral pneumonia 
 Antibiotics may be considered as a coexisting bacterial infection exists 
in 30% of cases 
 An appropriate antiviral (e.g. Amantadine, Rimantidine, Osetamivir, 
Zanamivir) should be considered for the child with pneumonia due to 
Influenza 
Prognosis 
 Uncomplicated community-acquired bacterial pneumonia show 
improvement in clinical symptoms within 48-96 hr of initiation of 
antibiotics. 
 Radiographic evidence of improvement lags behind clinical improvement. 
 Causes of none improvement with appropriate antibiotic therapy: 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1989),
   ('2d89ac7b-2d08-5167-9d9b-4cfe80a3e85e', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 172, 185, 0, 'Page | 2 Illustrated Baby Nelson 
172
 
 
 Complications, such as empyema 
 Obstruction from endobronchial lesions or foreign body 
 Bacterial resistance 
 Pre-existing Diseases: as causes of recurrent pneumonia*** 
 Nonbacterial Etiologies such as viruses and aspiration 
 
Recurrent pneumonia 
 Defined as 2 or more episodes in a single year or 3 or more episodes 
ever, with radiographic clearing between occurrences 
 Underlying disorder 
1. Hereditary disorders 
 Cystic fibrosis 
 Sickle cell disease 
2. Immunodeficiency: Primary or secondary 
3. Disorders of Cilia 
 Immotile cilia syndrome 
 Kartagener syndrome 
4. Anatomic disorders 
 Aspiration (oropharyngeal incoordination) 
 Gastroesophageal reflux 
 Tracheoesophageal fistula (H type) 
 Foreign body 
 Bronchiectasis 
 Pulmonary sequestration 
 Lobar emphysema 
(Nelson textbook of pediatrics)
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 964),
   ('6066e485-5920-52d1-a6d1-c2da4461f49a', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 173, 186, 0, 'Page | 3 
 Illustrated Baby Nelson 
173
 
 
 
 Acute inflammation of the bronchioles 
 Usually viral infection 
 Respiratory syncytial virus (RSV) in 50% of cases 
 Others: human metapneumovirus, Adenovirus, Para influenza and 
Mycoplasma 
 Incidence 
 
 Age: The 1st 2 years of life (peak age ~ 6 months) 
 Season: more in winter and spring 
 More in boys who are not breast fed 
Pathogenesis 
 Viral invasion of small bronchioles mucosa & submucosa invaded 
o acute inflammation o bronchiolar obstruction by edema, mucus 
and cellular debris 
 Impaired pulmonary gas exchange ( hypoxemia , hypercapnia) may 
occur with severe disease 
Clinical picture 
Symptoms 
 Mild upper respiratory catarrh (rhinitis , mild fever) for few days then 
 Gradually occurring dyspnea, cough and wheezy chest 
 Along with irritability, difficult feeding, air hunger 
 Apnea may be more prominent in very young infants (<2 mo old) or 
former premature infants 
Signs 
1. Respiratory distress 
 Tachypnea, retractions, grunting ± cyanosis 
 Degree of tachypnea does not always correlate with the degree of 
hypoxemia or hypercarbia, so pulse oximetry and noninvasive 
determination of carbon dioxide are essential 
2. Hyperinflation o Ptosed liver and spleen 
3. Chest examination: 
Inspection 
o Hyperinflated chest , prolonged expiration 
Palpation 
o May be palpable wheezes and decreased TVF 
Percussion 
o Bilateral hyper resonance 
Auscultation 
o Diminished vesicular breath sounds. 
o Prolonged expiration. 
o Bilateral expiratory wheezes 
o Bilateral fine crackles 
Acute Bronchiolitis
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1681),
   ('d80ecabb-a4cb-5abe-8f02-a9778ca99fcc', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 174, 187, 0, 'Page | 2 
 Illustrated Baby Nelson 
174
 
Complications 
 Dehydration o due to tachypnea & anorexia 
 Lung collapse or pneumothorax o sudden deterioration 
 Respiratory failure 
 Heart failure 
Investigations: Diagnosis of acute bronchiolitis is mainly clinical 
 Chest X-ray
R Indicated only for severe illness or bacterial superinfection suspected
R Shows: 
 Hyperinflation (horizontal ribs , flat diaphragm)
 Bilateral perihilar infiltrates ± areas of atelectasis 

Blood tests: 
R ESR, CRP and white blood cell count o are usually normal 
R Arterial blood gases for severe disease 
 Detect the virus by cell culture or viral antigen /RNA by PCR using 
nasopharyngeal aspirate 
Differential diagnosis: From other causes of wheezy infants e.g.: 
x Bronchial asthma: suggested by 
 Recurrent attacks of wheezy chest ± viral prodrome 
 Related to certain allergens or exercise 
 Respond to anti-asthma therapy(bronchodilator trial) 
 Relatives with atopy or asthma/presence of atopy or dermatitis 
x Congestive heart failure 
x Aspiration syndromes /Foreign body inhalation. 
x Cystic fibrosis 
x Infections e.g. Pulmonary TB, Pertussis 
Treatment 
Treat at home or hospital? 
Hospitalize if risk factors for severe disease exist e.g. 
 Infants younger than 3 months 
 Severe respiratory distress or apnea, oral feedings intolerance 
 Preterm birth 
 Underlying comorbidity 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1478),
   ('ccb08b0e-0912-57aa-9b3f-088c8d9883a6', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 175, 188, 0, 'Page | 3 
 Illustrated Baby Nelson 
175
 
The mainstay of treatment is: 
"Supportive care" 
 Nurse sitting with head and chest elevated at a 30-degree angle with 
neck extended 
 Humidified cool oxygen inhalation with high-flow nasal cannula 
 Frequent suctioning of nasal and oral secretions often provides relief 
of distress 
 Care of feeding ( more calories are required) 
 Parenteral fluids if risk of aspiration exists with respiratory distress 
 Treat complications e.g. 
R Antibiotic therapy if secondary bacterial pneumonia suspected 
R CPAP or intubation and mechanical ventilation if deterioration 
with exhaustion or persistent apnea 
Non evidence based and controversial strategies 
1. Inhaled bronchodilator* 
 Don''t modify disease course 
2. Steroids* 
 
 Don''t modify disease course 
 Prolong virus shedding 
3. Combined nebulized epinephrine* & 
oral dexamethasone 
4. Nebulized hypertonic saline 
5. Heliox 
 Under ongoing studies 
 Short term relief in severe cases 
6. Chest physiotherapy 
7. Cough sedatives 
 Should be avoided 
* Frequently used 
Home oxygen therapy 
 Low risk cases that require oxygen can be discharged ER on home oxygen 
 Criteria for home oxygen therapy includes 
1. Mild illness as evident by feeding well ,alert and active; minimal 
retractions; respiratory rate <50 breaths/min, no apnea 
2. Age: 2 mo-2 yr of age with first episode of wheezing during RSV 
season 
3. Reliable family: good access to healthcare, can manage 
secretions by bulb suctioning 
4. Absent: 
 Toxic appearance or proven bacterial disease 
 Comorbidities: Cardiac, pulmonary, immunodeficiency, or 
neuromuscular 
 
(Nelson textbook of Pediatrics )
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1772),
   ('cf466d0d-9967-5f2d-8f16-49eebc822542', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 176, 189, 0, 'Page | 2 Illustrated Baby Nelson 
176
 
 
 
Antiviral 
Ribavirin aerosol 
Indications: risky infants (see later) 
Side effect: controversial benefits and very costly 
 
Prevention 
 Meticulous hand hygiene is the best measure to prevent nosocomial 
transmission. 
 Monoclonal antibody to RSV F protein (Palivizumab) I.M is given before 
and during RSV season for risky infants < 2 yr of age with: 
 Chronic lung disease 
 Gestational age is less than 35 weeks 
 Comorbidities e.g. congenital heart disease, immunodeficiency, 
neuromuscular disorders 
 
Prognosis 
 The median duration of symptoms is approximately 14 days; the first 2-3 
days are the most critical 
 Mortality rate | 1% due to: apnea , respiratory failure, dehydration 
 There is higher incidence of wheezing and asthma in children with a 
history of bronchiolitis 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 927),
   ('db651d2e-4ab0-5e6a-b1dc-e380883fa7b6', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 177, 190, 0, 'Page | 3 
 Illustrated Baby Nelson 
177
 
 
 
 
Definition 
Asthma is a chronic inflammatory condition of the lung airways resulting in 
airways hyper responsive to various stimuli and episodic airflow obstruction 
with high degree of reversibility 
Incidence 
 Boys/ girls: 2:1 before puberty and 1:1 after puberty. 
 Most asthmatic children become symptomatic before 5th year 
Risk factors/associations 
 Parental asthma 
 Other allergies e.g. eczema, allergic rhinitis, food allergies 
 Rhinitis, sinusitis & gastro esophageal reflux disease (GERD). 
 Early weaning from breast milk before 4 months. 
Pathogenesis 
 Genetic predisposition 
 Imbalance between T Helper 1 lymphocytes (Th1) & and T Helper 2 (Th2) with 
raised Th2 o excessive release of proinflamatory cytokines (IL4, IL5, IL13) 
 Exposure to asthma triggers 
 
- Accumulation of IgE in airways and blood (Type 1 hypersensitivity; atopy) 
- Increased activated mast cells, eosinophils and chronic inflammatory cells in 
airways 
 
 
 Bronchoconstriction and airways inflammation with edema, nmucus, nchronic 
inflammatory cells 
 
 Airways narrowing especially in expiration 
 Persistent airway inflammation leads to 
 
- Collagen deposition beneath basement membrane. 
- Hypertrophy of muscles & glands. 
 
 Airway remodeling and persistent narrowing (Chronic obstructive airway 
disease (Cor Pulmonale) 
 Asthma triggers includes 
 Respiratory viral infections 
 Animals with fur, dust mites, cockroaches 
 Aerosol chemicals 
 Changes in temperature e.g. early morning 
 Drugs (aspirin, beta blockers) 
Bronchial Asthma 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1693),
   ('a5db9bc5-5c77-5604-8565-30fef59c8d00', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 178, 191, 0, 'Page | 2 Illustrated Baby Nelson 
178
 
 
 
 Exercise (? Air drafts moving in and out) 
 Pollens 
 Smoke, tobacco smoke 
 Strong emotional expression 
Clinical picture 
Asthma is strongly suggested with 
1. History of any of the following: 
 Cough, worse particularly at night 
 Recurrent wheeze, difficult breathing or chest tightness 
2. Symptoms occur or worsen 
 At night, awakening the patient 
 In a seasonal pattern 
 In the presence of a trigger 
3. Symptoms respond to short-DFWLQJLQKDOHGȕ-agonist 
4. History of other allergies eczema, hay fever,… 
5. History of asthma or atopy in other family member 
6. History of Patient''s colds often "go to the chest" or take longer to clear up 
During an attack (Exacerbation) 
 Irritability, restlessness. 
 Respiratory distress (tachypnea, retractions…) 
 Chest signs 
 Chest wheezing (a normal chest examination does not exclude asthma) 
Inspection 
o 
+\SHULQIODWHGFKHVWSURORQJHGH[SLUDWLRQDQGĻPRYHPHQW 
Intercostals and subcostal retractions 
Palpation 
o 
Decreased TVF and may be palpable wheezes 
Percussion 
o 
%LODWHUDOK\SHUUHVRQDQFHZLWKĻKHSDWLF FDUGLDFGXOOQHVV 
Auscultation o 
 
o 
Diminished vesicular breath sounds with prolonged 
expiration 
Bilateral expiratory wheezes 
 
Types of asthma 
1. Transient non atopic wheezing 
 Triggered by common respiratory viral infections 
 Usually resolves during childhood 
2. Persistent atopy-associated asthma 
 Associated with atopy 
 Clinical e.g., atopic dermatitis in infancy, allergic rhinitis, food allergy 
 Allergen sensitization, Ĺ,J(DQGEORRGHRVLQRSKLOV 
 Tend to persist into later childhood with lung function abnormalities 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1765),
   ('b7164915-6401-5898-a0a9-ff0d8df9ba13', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 179, 192, 0, 'Page | 3 
 Illustrated Baby Nelson 
179
 
Workups in asthma 
"Diagnosis of bronchial asthma is mainly clinical" 
1. Lung function tests 
Usually feasible in children > 5 yr of age 
A. Spirometry (in clinic) 
 FEV1 Forced expiratory volume in the 1st second 
 FEV1:FVC ratio Forced expiratory volume in the 1st second/ Forced 
vital capacity 
Findings in asthma 
 Low (relative to percentage of predicted norms or previous best) 
 Improve after inhaled bronchodilator 
 Worsen after exercise challenge 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
B. Peak Expiratory Flow (PEF) 
 Used for home monitoring 
 Less sensitive than spirometry 
 
 
 
 
2. Immunologic 
 High IgE and eosinophils in the blood and sputum 
 Allergen sensitization : Skin testing with suspected allergens 
3. Chest X-ray (During exacerbation) may show 
 Hyperinflation. 
 May detect complications e.g. collapse, pneumothorax 
Spirometry is recommended at 
least annually and more often if 
asthma is poorly controlled or 
abnormal lung functions detected
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1111),
   ('40306d9a-5a8f-5bf0-8018-43da85221f1e', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 180, 193, 0, 'Page | 2 Illustrated Baby Nelson 
180
 
 
 
Treatment 
Medications used in bronchial asthma 
 
1. 6KRUWDFWLQJȕ$JRQLVWV6$%$ 
 Preparations 
 
 
 Salbutamol 
 Albuterol 
 Levalbuterol 
 Action 
 Selective E2 agonists; induce quick and short lived 
bronchodilatation 
 Duration 
 Short acting ; 4- 6hrs 
 Indication 
 Drugs of choice for acute asthma symptoms ("rescue" 
medication) and for preventing exercise-induced 
bronchospasm 
(2.5 - 5 mg by inhalation; dilute with saline to 3 mL) 
 Side effects 
 
 Tachycardia and tremors (less with Levalbuterol) 
 Hypokalemia 
 Overuse of SABAs as a "quick fix" for asthma, rather 
than using controller medications is associated with an 
increased risk of death from asthma 
2. Ipratropium bromide 
 Parasympatholytic 
 Used primarily as add on to SABA in treatment of acute severe asthma 
 125 - 250 microgram by inhalation; dilute with saline to 3 mL 
 Useful in wheezing due to bronchmalacia 
 Side effects : Mild atropine like /less potent than the ȕ-agonists 
 
 
1. Steroids 
a. Inhaled corticosteroids (ICS) 
 Preparations 
 
 
 Beclomethasone (Qvar) 
 Budesonide (Pulmicort) 
 Fluticasone (Flixotide) 
 Ciclesonide (Alvesco) 
 Action 
 Potent anti-inflammatoryĺ reduce airway chronic 
inflammation and remodeling 
 ĹĹ expression of E-receptors in bronchial muscles 
 Indication 
 First-line treatment for persistent asthma 
 Available in metered-dose inhalers (MDIs), dry 
powder inhalers (DPIs), or suspension for nebulization 
Controller medicines
 
Reliever medicines
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1647),
   ('938d41d0-143b-5691-88eb-c32b84104e50', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 181, 194, 0, 'Page | 3 
 Illustrated Baby Nelson 
181
 
 Side effects 
 
a. Oral candidiasis (thrush) 
b. Dysphonia (hoarse voice) due to vocal cord myopathy 
Both are minimized by: 
 Using a spacer with MDI( reduce oropharyngeal 
deposition of the drug) 
 Mouth rinsing after ICS use 
c. ? Steroids systemic effects with high dose, long term ICS 
 
b. Systemic corticosteriods 
 Preparations 
 
 Oral: Prednisolone 
 Parenteral: Methyleprednisolone, Hydrocortisone 
 Indication 
 Short courses to treat asthma exacerbations 
 Rarely, long courses in patients with severe disease 
who remain symptomatic despite optimal treatment 
 Precaution 
 Children who require routine or frequent short courses 
of oral corticosteroids, especially with concurrent highdose ICSs, should receive corticosteroid adverse 
effects screening and osteoporosis preventive 
measures 
 
2. Long Acting E2 Agonists (LABA) 
 Preparations 
 
 
 
ĺ
¥ 
 Action 
 
E
 
 Indication 
 
 
 Precaution 
 
 
 
 Risks 
 
 
 
3. Leukotriene receptor antagonist (LTRAs) 
 Preparations 
 
 Montelukast (Singulaire); chewable tablets or sachets, 
licensed above 6 months 
 Zafirlukast, licensed above 5 years 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1272),
   ('d3120075-0f79-5873-b29a-5c2939b35e0b', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 182, 195, 0, 'Page | 2 Illustrated Baby Nelson 
182
 
 
 
 Action 
 Leukotriene receptor antagonist with antiinflammatory and a bronchodilator effect 
 Indication 
 Alternative treatment for mild persistent asthma 
 Add-on medication with ICS for moderate persistent 
asthma 
 Reduce exercise-, aspirin-, and allergen-induced 
bronchoconstriction. 
 Precaution 
 Less effective than ICSs in patients with mild 
persistent asthma 
 Risks 
 Montelukast has rarely been associated with mood 
changes and suicidality
 
4. Theophylline 
 Action 
 3KRVSKRGLHVWHUDVH LQKLELWRU ĺ EURQFKRGLODWDWLRQ DQG
anti-inflammatory 
 Use 
 Alternative monotherapy controller agent for older 
children and adults with mild persistent asthma 
 It is no longer considered a first-line agent for young 
children 
 Precaution 
 Narrow therapeutic window; therefore, when it is used, 
serum theophylline levels need to be routinely 
monitored 
 Overdose 
 Headaches, vomiting, cardiac arrhythmias, seizures, 
and death 
 
5. Sodium cromoglycate 
 Mast cell stabilizer 
 Inhibit exercise-induced bronchospasm, they can be used in place of 
SABAs, especially in children who develop unwanted adverse effects 
with ȕ-agonist therapy (tremor and elevated heart rate). 
 Not a preferred controller ; must be administered frequently (2-4 
times/day) and are not nearly as effective daily controller medications 
 
Asthma medicines delivery systems 
 
 
 
 
 
 
 
 
Metered dose inhaler with 
a spacer 
Dry powder inhaler with 
metered dose turbohaler 
Solution for nebulization 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1646),
   ('eaf04089-8b6a-5d90-9569-56dc0394cb66', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 183, 196, 0, 'Page | 3 
 Illustrated Baby Nelson 
183
 
Management of acute asthma exacerbation 
A. At Home 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
B. Emergency department treatment 
Assessment of severity 
 
Mild 
Moderate 
Severe 
 Altered consciousness 
Absent 
Agitated, confused 
 Cyanosis 
Absent 
Likely present 
 Dyspnea 
On walking 
On talking 
At rest 
 Speaks 
In sentences 
Phrases 
In words 
 Pulse 
Normal 
Mild tachycardia 
Marked tachycardia 
(> 180bpm in young) 
 Pulsus paradoxus 
Normal 
Less than 20 mmHg 
20-40 mmHg 
 Wheezes 
End expiratory Holo expiratory 
Exp and inspiratory 
May be quiet 
 Retractions 
Absent 
Common 
Usual 
 Peak expiratory flow 
70% 
40-69%* 
<40%* 
 Oximetry in air 
> 95 % 
90 -95 % 
< 90% 
 PaCO2 
< 42 mmHg* 
> 42 mmHg 
 PaO2* 
Normal* 
< 60 mmHg 
* Means test not usually necessary 
 
Signs of acute severe asthma with imminent respiratory arrest 
 Drowsy or confused 
 Paradoxical thoracoabdominal movement 
 Absence of wheeze 
 Bradycardia, Absent pulsus paradoxus (due to respiratory muscle fatigue) 
Status asthamticus : A severe asthma exacerbation that does not improve with 
standard therapy 
 Inhaled SABA (Salbutamol): 2.5 - 5 mg with saline by nebulizer up to 
3 treatments in 1 hr OR 
 2-6 puffs SABA by MDI (puff=100 mcg) up to 3 treatments in 1 hr 
 Resolution of symptoms 
 No symptoms over the next 4 hr 
 ,PSURYHG3()RISHUVRQDOEHVW 
 Incomplete response to initial treatment 
 Persistent PEF < 80% of personal best 
 Deterioration 
 Continue SABA at 3-4 hr intervals 
for 1-2 days 
 Contact your physician for advice 
 
Seek urgent medical advice
 
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1715),
   ('71115aad-8cc4-5b57-bf0c-61ca1df8ae9b', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 184, 197, 0, 'Page | 2 Illustrated Baby Nelson 
184
 
 
 
Action plan 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
Outcome at 1 hour 
 
 
 
 
 
 
 
 
 
 
 
 
 
* High risk patients include: 
 Previous severe asthma exacerbation (intensive care unit admission) 
 Two or more hospitalizations for asthma in past year 
 Three or more emergency department visits for asthma in past year 
 Low birthweight 
 Poverty 
(Nelson Text Book of Pediatrics, 2016) 
 Pulse oximetry in air 
 High flow oxygen to keep O2 saturation > 92% 
 SABA (Salbutamol): 2.5 - 5 mg with saline by nebulizer or 2 to 6 
puffs by MDI plus spacer 
(Repeat every 20 minutes for the 1st hour) 
 Ipratropium bromide: 125 - 250 mcg by nebulizer; if no adequate 
response to the first salbutamol nebulizer 
(Repeat every 20 minutes for the first hour only) 
 Oral Corticosteroids (1-2mg/kg in divided doses) in moderate to 
severe asthma exacerbations to hasten recovery and prevent 
recurrence of symptoms 
 Epinephrine( 1:1000) :0.3-0.5 mg IM or SC may be given in 
severe cases 
Good outcome: 
 Normal physical findings 
 PEF >70% of predicted or personal best 
 Oxygen saturation >92% in room air for 
4 hr 
1. :HDQJUDGXDOO\ĺ6$%$every 3-4 hr 
2. ,IRQDFRQWUROOHUGUXJ,&6ĺFRQWLQXH
it during and after exacerbation 
3. Continue oral steroids for 3-7 days 
 Moderate to severe 
exacerbations that do not 
adequately improve within 
 1-2 hr of intensive treatment 
 High risk patients* 
 
Admission 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1549),
   ('d00bcd9e-a52b-5cac-adf8-0db3493f2071', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 185, 198, 0, 'Page | 3 
 Illustrated Baby Nelson 
185
 
C. Admission to hospital /PICU 
 Admission to an PICU is indicated for patients with 
 Severe respiratory distress 
 Concern for potential respiratory failure and arrest 
Action plan 
 Cardio-pulmonary monitoring 
 Oxygen 
 Salbutamol 
 Nebulizer every 20 min as needed, then every 1-4 hr as needed 
Or 
 Continuous nebulization with oxygen: 5-15 mg/hr 
 Corticosteroids: Short course 3-7 days 
 Oral: Prednisone 1-2 mg/kg 
 Parenteral: Methyleprednisolone or Hydrocortisone 
Ipratropium bromide nebulizer (poor evidence; no longer recommended) 
 
 
Persistent severe dyspnea and high-flow oxygen requirements 
 
R Obtain IV access, take electrolytes , glucose and ABG 
R CXR in life threatening attack or suspected pneumothorax (deteriorate after 
a period of improvement) 
R Start IV maintenance fluids 
 Dextrose 5% in 0.45% saline with 20-mmol/l kcl 
 At 70-80% of maintenance 
 Correct any dehydration 
R Replace nebulizer by IV Salbutamol ; Watch for low potassium and ECG 
monitoring for arrhythmias 
 
Critically ill or at risk for respiratory failure 
Available options 
x Epinephrine IM or SC 
x Magnesium sulphate (25-75 mg/kg, maximum dose 2.5 g, given 
intravenously over 20 min) 
x Aminophylline ; loading dose 5-10 mg/kg over 1 hour followed by 
maintenance 1 mg /kg/hour (0.7 mg /kg/hour if >10 years) 
x Inhaled heliox (helium and oxygen mixture) 
x Assisted /mechanical ventilation 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1543),
   ('29895463-fd2b-5584-ab57-46065073a0f7', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 186, 199, 0, 'Page | 2 Illustrated Baby Nelson 
186
 
 
 
After exacerbation resolution: 
1. Space SABA gradually 
2. Continue steroids for full 3-7 days 
3. Start controller therapy 
4. Families of all children with asthma should have a written action plan to 
guide their recognition and management of exacerbations 
5. With history of life-threatening episodes, especially if abrupt-onset in 
nature, providing an epinephrine autoinjector and, possibly, portable 
oxygen at home should be considered 
(Nelson Text Book of Pediatrics, 2016) 
 
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 620),
   ('0cc42d82-91f1-57b7-9b1e-25e8d238cad7', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 187, 200, 0, 'Page | 3 Illustrated Baby Nelson 
187
Long term asthma management 
 
I. Assessing asthma severity and initiating treatment (For patients who are not currently taking long-term control medications) 
 
 
 
Persistent 
 
Intermittent 
Mild 
Moderate 
Severe 
1. Daytime symptoms 
(Wheezing, cough, breathless) 
 2 days/wk 
> 2 days/wk but not daily 
Daily 
Throughout the day 
2. Nocturnal symptoms /awakening (Nocturnal cough, wheezing, breathless) 
Age < 5 yr 
0 
1-2 /mo 
3-4 /mo 
>1 /wk 
$JH\U 
 2 /mo 
3-4 /mo 
>1 /wk 
Often 7 /wk 
3. Need for reliever 
 2 days/wk 
> 2 days/wk 
Daily 
Several times per day 
4. Limitation of activities 
(Cough ,wheeze, or breathless 
on exercise, play or laugh) 
None 
Minor limitation 
Some limitation 
Extreme limitation 
5. Lung function (FEV1); 
age 5 yr 
> 80% predicted 
 80% predicted 
60-80% predicted 
< 60% predicted 
Recommended step for 
initiating therapy 
Step 1 
Step 2 
Step 3 
Step 3 or Step 4', 957),
   ('25b3cded-d21e-59f8-88a6-e585da1a00e6', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 188, 201, 0, 'Page | 2 Illustrated Baby Nelson 
188
II. Stepwise Approach for Managing Asthma in Children 
Step 1 
Step 2 
Step 3 
Step 4 
Step 5 
Step 6 
Rescue treatment for all steps: As needed inhaled VKRUWDFWLQJȕDJRQLVW6$%$6KRUWFRXUVHRIRUDOVWHURLGV if exacerbation is severe or 
history of previous severe exacerbations 
Move to step 2 if : 
Rescue treatment is 
needed more than 
twice a week 
or 
If night-time 
symptoms at least 
once a week 
or 
If exacerbation 
in the last 2 years 
Low dose ICS 
Or 
Montelukast 
Medium dose ICS 
 
 
OR 
Low dose ICS + 
Montelukast* 
OR 
Low dose ICS + LABA 
Medium dose ICS 
+ Montelukast* 
OR 
Medium dose ICS 
+ LABA 
 
High dose ICS 
+ Montelukast* 
OR 
High dose ICS 
+ LABA 
 
High dose ICS 
+ Montelukast* 
OR 
High dose ICS 
+ LABA 
+ 
Oral glucocorticoids 
lowest dose 
Modified-release oral theophylline may substitute Montelukast 
 
 
 
Consider Anti IgE(Omalizumab) for patients 
above 12 years with Allergies 
 
Consider subcutaneous allergen immunotherapy for patients who have allergic asthma 
Patient education, environmental control, and management of comorbidities 
* For those less than 4 years 
 
Step Down or Step Up gradually 
According to assessment of current clinical control (See next table)', 1262),
   ('8dd9273a-e589-5aa7-9a93-2c4110707eb1', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 189, 202, 0, 'Page | 3 Illustrated Baby Nelson 
189
III. Assessment of current clinical control (preferably over 4 weeks) 
 
Characteristic 
Well controlled 
(All of the following) 
Not well controlled 
(Any measure in any week) 
Very poorly controlled 
 
Daytime symptoms 
None or < 2 /week; very short 
>2 days/wk 
 Throughout the day 
Nocturnal symptoms /awakening 
Age < 5 yr 
$JH\U 
 
 1 /mo 
 1 /mo 
 
> 1 /mo 
 2 /mo 
 
>1 /wk 
 2 /wk 
Limitation of activities 
None 
Some limitation 
Extreme limitation 
Need for reliever 
 2 days/wk 
> 2 days/wk 
Several times per day 
Lung function (FEV1 or PEF) 
> 80% predicted 
60-80% predicted 
< 60% predicted 
Exacerbations requiring systemic 
steroids courses 
0-1/yr 
 2/yr 
> 3/yr 
 
 
Action 
 
Step Down gradually to the least 
medication necessary to maintain 
control if asthma is well 
controlled at least 3 months 
 
Step Up gradually after checking inhaler technique, 
adherence, environmental control, and comorbid 
condition 
Improvement should be seen within 4-6 weeks', 1028),
   ('1e0e8572-212f-580a-8f33-74335773aaec', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 190, 203, 0, 'Page | 2 Illustrated Baby Nelson 
190
 
 
 
IV. Avoid exposure to triggering agents 
 Eliminate or reduce problematic environmental exposures 
 Avoid drugs, foods, and additives known to cause symptoms. 
 Avoid allergens as suggested by skin testing 
 Treat co-morbid conditions: sinusitis, GERD and rhinitis. 
 Give annual influenza vaccine unless egg allergic 
 In exercise induced asthma give: 
 SABA inhalation o 10 minutes before exercise 
 or 
Montelukast oral o 1 hour before exercise 
 
V. Patient education 
x Explain basic facts about asthma 
x Written asthma management plan 
x Demonstrate optimal technique of use of asthma devices 
x Insist on adherence to medications 
x Ensure avoidance of risk factors 
x Two to four asthma checkups per year for: 
1. Frequency of asthma symptoms during the day, at night, and with 
physical Exercise 
2. Frequency of "rescue" SABA medication use and refills 
3. Lung function measurements (spirometry) for older children at least 
annually 
4. Number and severity of asthma exacerbations 
5. Presence of medication adverse effects since the last visit 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1195),
   ('cba3e2af-afee-597f-abeb-58c0ab1e5410', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 191, 204, 0, 'Page | 3 
 Illustrated Baby Nelson 
191
 
 
 
 
 
Definition of wheeze 
- Expiratory musical continuous sound 
- Due to partial obstruction of small bronchi & bronchioles 
- Can be sibilant or sonorous 
- May be also inspiratory in severe obstruction 
Possible mechanisms 
- Bronchoconstriction (spasm of airways smooth muscles) 
- Bronchial mucosal edema. 
- Excessive, viscid secretions inside airways lumens 
Causes 
 
Acute 
Chronic /recurrent 
 Acute bronchiolitis. 
 Bronchial asthma exacerbation 
 Foreign Body inhalation 
 Congestive Heart failure(e.g. 
congenital heart diseases or 
cardiomyopathy) 
 Aspiration e.g. GERD 
 Bronchial asthma 
 Congestive heart failure 
 Cystic fibrosis 
 Dynamic airway collapse: e.g. 
bronchomalacia &tracheomalacia 
 Recurrent aspiration e.g. 
 GERD 
 Tracheo esophageal fistula 
 Neuromuscular disorders 
 Foreign body 
 Pulmonary tuberculosis(LN+) 
 Airway compression by: lymph 
nodes, vascular ring or tumor 
 

 
Differential diagnosis of asthma 
(Wheezy Chest)
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1116),
   ('7474fd9e-b4d7-5a59-960b-907ef5009df7', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 192, 205, 0, 'Page | 2 Illustrated Baby Nelson 
192
 
 
 
Foreign body aspiration 
Clinical picture 
Squeals 
1. Immediate expelling by cough reflex 
2. Retained foreign body: manifestations differs according to site 
Type of obstruction 
Laryngeal 
Tracheal 
Bronchial 
Partial 
- Respiratory distress 
- Stridor 
- Hoarsness of voice 
- Aphonia 
- Metallic cough 
- Chest 
wheezes 
Complete 
- Suffocation 
- Respiratory distress 
- Cyanosis 
- Collapse 
- Abscess 
- Pneumonia 
History 
 Commonly reported in children 3months to 6 years 
 History of sudden chocking or frank history of foreign body aspiration 
 Triphasic history may be obtained: 
- Initial phase: cough, chocking, stridor or gagging 
- Silent phase: if foreign body pass and impact in smaller airways 
- Phase of complications: recurrent pneumonia , abscess, bronchiactasis 
Signs 
R Fixed localized wheeze; unresponsive to treatment. 
R Unexplained lung collapse 
R Diminished breath sound over one lung, one lobe or one segment 
R Mediastinal shift (unilateral collapse or emphysema). 
R "Same site" recurrent pneumonia, abscess, bronchiectasis 
Chest X-ray 
- Positive only in about 50% of cases 
- May show obstructive collapse or obstructive emphysema in expiratory film. 
Treatment 
A. Without respiratory distresso bronchoscopic extraction 
B. With respiratory distress: 
1. If the child is breathing well: 
- Encourage cough to clear the foreign body 
- Be vigilant for any deterioration 
2. If cough becomes ineffective: 
 Try to assist expulsion of the foreign body 
 Provide rescue breathing in between trials. 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1671),
   ('4b353678-eb03-572a-9074-63e184becc82', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 193, 206, 0, 'Page | 3 
 Illustrated Baby Nelson 
193
 
 Use the Alert, Verbal, Pain, Unresponsive pediatric scoring system(AVPU) 
to determine both a child''s level of consciousness and cerebral cortex 
function 
 If trials fail and infant becomes unconscious, attempt to visualize foreign 
body and remove manually. 

i. First aid for the choking infant < 1 year of age 
 Hold infant prone with the head down. 
 Give 5 interscapular back blows, using heel of hand. 
 Turn the infant supine, with head dependent and perform 
 5 quick downward chest thrusts . 
 
ii. First aid for the choking child older than 1 year of age 
A) In conscious patient  abdominal thrust in sitting or 
standing (Heimlich maneuver): 
 Encircle the child chest with arms from behind. 
 Place one fist against patient''s abdomen in midline 
just below tip of xiphoid. 
 Grasp fist with other hand and exert 5 quick, upward 
thrusts. 
 
B) In unconscious patient abdominal thrust in lying down: 
 Place the patient supine. 
 Open patient airway using chin lift or jaw 
thrust. 
 Place heel of one hand on child''s abdomen 
just below costal margins. 
 Place the other hand on top of the first hand. 
 Press both hands into abdomen with quick, 
upward thrusts in midline. 
 
iii. Further interventions 
 - Laryngoscopic removal. 
 - If failed; push foreign body more distally. 
 - If failed, perform immediate cricothrotomy 
Prevention 
Avoid chocking materials in infants and young children e.g. small toys, nuts, 
popcorn 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1586),
   ('4617eb5e-fc0a-5375-aa9f-6dd467f1a6de', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 194, 207, 0, 'Page | 2 Illustrated Baby Nelson 
194
 
 
 
 
 
Definition: Fibrinous inflammation of the pleura. 
Causes 
 Infections: Viral pneumonia, bacterial pneumonia, tuberculosis 
 Chest wall trauma 
 Collagen diseases e.g. Rheumatic fever, systemic lupus erythematosus 
Clinical picture 
R Manifestations of the cause 
R Chest pain: Stitching, n with deep respiration, cough & sneezing 
R Patients may prefer to lie on same side. 
R Auscultation: Pleural rub: - Scratchy sound. 
 - Decrease by holding breathing. 
Treatment: - Treat the cause. 
 
 
 
 
 - Analgesics. 
 
 
 
 
 Normally, only 4-12 mL of fluid is present in the pleural space, but if 
formation exceeds clearance, fluid accumulates. 
 Definition: Serofibrinous inflammation of the pleura. 
Types of effusion 
 
Transudate 
Exudate 
Bloody 
Cheylous 
Characters 
- Clear; straw colored 
- Proteins < 3gm/dl 
- p Cells (mesenchymal) 
- p Specific gravity 
- Sterile 
- pLactate dehydrogenase 
 
- Turbid ; opaque 
- > 3 gm/dl. 
- n Cells (PMNLs) 
- n Specific gravity (>1015) 
- May reveal organisms 
- Lactate dehydrogenase >200 iu /l 
 
Bloody with RBCs 
on mic. examination 
 
- Milky white 
- Dissolved with 
 ether 
- Spread on filter 
 paper 
Mechanisms 
- Increased hydrostatic 
capillary pressure 
- Decreased plasma 
osmotic pressure 
 
Increased capillary permeability 
due to inflammation , malignancy, 
mediastinal or chest wall diseases 
 
 
Impaired lymphatic 
drainage 
Causes 
Passive transudation in 
renal, cardiac & hepatic 
causes of generalized 
edema 
 
 
- Pneumonia. 
- T.B. 
- Ruptured Lung abscess 
- Mediastinitis 
- SLE, uremia, metastasis 
- T cell lymphoma. 
 
- Tumors 
- Trauma 
- Hemorrhagic blood 
 Diseases 
 
Thoracic duct 
obstruction or 
trauma 
Dry Pleurisy 
 
Serofibrinous Pleurisy 
(Pleural Effusion) 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1892),
   ('d7c782a5-24c7-5e48-bdec-21dc91a90b51', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 195, 208, 0, 'Page | 3 
 Illustrated Baby Nelson 
195
 
Clinical picture 
Symptoms 
 Manifestations of the underlying cause (e.g. fever, dyspnea,.….) 
 Respiratory distress 
 Chest pain: dull aching pain; patient prefers to lie on the affected side 
Chest examination 
 Small effusion: 
Clinical picture of an underlying cause e.g. pneumonia o 
bronchophony, bronchial breathing and crepitation 
 Massive effusion 
 Inspection 
o Unilateral bulge, full intercostal spaces with 
diminished movement 
 Palpation 
o Decreased TVF & trachea shifted to opposite side 
 Percussion 
o Stony dullness, rising to axilla 
 Auscultation o 
o 
Marked diminished breath sounds (or absent). 
Aegophony (nasal tone of voice) may present at 
the top of effusion due to kinked bronchi 
Investigations 
1. Chest X-ray in supine and upright positions: 
 In small effusion: homogenous opacity just obliterating costophernic angle 
 In moderate to large (Massive) effusion: homogenous opacity 
 - Filling the costophernic angle 
 - Rising to the axilla. 
 - With shift of the mediastinum to the opposite side 
 
 
 
 
 
 
 
Mild left sided effusion 
 Moderate right sided effusion 
Massive left sided effusion 
 
2. Chest ultrasonography 
 Diagnostic for pleural fluid 
 Guide thoracentesis/ Chest tube insertion 
 
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1380),
   ('0b92f396-05d3-5d9c-96b3-cbbd4896ef42', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 196, 209, 0, 'Page | 2 Illustrated Baby Nelson 
196
 
 
 
3. Thoracentesis: 
 a. Inspect the fluid: 
- Straw colored o Transudate 
- Turbid 
o Exudates 
- Milky white 
o Chylous 
- Fetid odor 
o Anaerobic infection , empyema 
b. Cytology: 
- Polymorph 
o Infection e.g. Pneumonia , early TB 
- Lymphocytes 
o TB, chylous , malignancy ; lymphoma 
- Esinophils 
o Parasitism, emboli 
- Red cells 
o Trauma, tumors,…… 
c. Order culture & sensitivity 
d. Biochemical examination: Mention from previous table
4. Tests for TB: tuberculin test, sputum analysis and culture 
5. Pleural biopsy, thoracoscopy and/ or broncoscopy: if TB or malignancy is 
likely 
 
Outcome of effusion 
 Massive effusion may impair cardiac function 
 Secondary pyogenic infectiono empyema 
 Organization of unresolving exudates may lead to fibrothorax 
 
Treatment 
1. Treat the cause 
2. Thoracocentesis is both diagnostic and therapeutic 
3. Thoracostomy tube drainage 
 Closed drainage using intercostal tube with underwater seal 
 Indicated for: 
a. Massive effusion 
b. Marked respiratory distress 
c. Effusion not resolved with medical treatment 
d. Empyema 
 Site of aspiration o 5th space mid axillary line 
 
Ӌ
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1274),
   ('7e2cd66e-d979-5c13-87ec-7beb9ba521b7', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 197, 210, 0, 'Page | 3 
 Illustrated Baby Nelson 
197
 
 
 
Definition 
 Exudative pleural effusion with marked nn pus cells 
 "Effusion is empyema if bacteria are present on Gram staining, pH is < 7.20, 
and there are >100,000 neutrophils/ȝL" 
Causes 
 Pneumonia (Pneumococci, Staph, H. influenza and klebseilla). 
 Rupture lung abscess. 
 Rupture abdominal abscess or subphernic abscess 
 Rupture of chest wall abscess 
 Secondary contaminated chest trauma or surgery 
 Secondary infection of an effusion 
 Secondary to infection from suppurated lower cervical lymph nodes 
Clinical picture 
1. Acute empyema: Same as pleural effusion with: 
- High fever, toxic patient. 
- Same side chest wall edema 
- High incidence of complications. 
2. Chronic empyema; empyema lasting for 3 months or more: 
Clinical 
Laboratory 
 Pale clubbing 
 Pallor 
 Low grade fever (Pyrexia) 
 Eventual fibrothorax ,collapse, 
with same side mediastinal shift , 
scoliosos and narrow ribs 
 Risk of amyliodosis 
 Anemia of chronic illness ; 
normocytic normochromic 
 Elevated ESR 
 Poly morph nuclear 
leucocytosis 
 
Complications 
1. Local spread to: 
 Lung o Bronchopleural fistula. 
 Abdomen o peritonitis. 
 Chest wall o empyema necessitatis. 
 Pericardium o purulent pericarditis. 
2. Distant spread e.g. Meningitis, septicemia,….. 
Investigations 
1. Chest X-ray: as effusion but; 
 Opacity is denser. 
 Ribs crowding 
 May be lung collapse in chronic cases 
Purulent Pleurisy (Empyema) 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1573),
   ('8785af9b-320b-5d53-8dd7-fed3713e5df2', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 198, 211, 0, 'Page | 2 Illustrated Baby Nelson 
198
 
 
 
2. Thoracocentesis 
 For character of the fluid (exudate with nn pus cells). 
 For culture & sensitivity. 
3. Ultrasonography or CT chest: Detect pleural fluid septa and loculated 
empyema 
4. Blood cultures: have a higher yield than cultures of the pleural fluid. 
Treatment 
1. Thoracostomy tube drainage 
 Closed drainage using intercostal tube with underwater seal(Open 
drainage may be necessary in chronic cases) 
 For about 1 week 
 More than one tube may be needed to drain pockets of pus. 
 Use intra pleural fibrinolytic agents (Streptokinase or Urokinase): 
 For 3-5 days 
 Promote drainage, decrease fever, and shorten hospitalization 
 Precaution: risk of anaphylaxis, and hemorrhage 
 
 
 
 
 
 
 
 
2. Antibiotics: According to culture and sensitivity for 2- 4 weeks 
3. Surgical decortications 
 Via video-assisted thoracoscopic 
surgery (VATS) or open thoracotomy 
 Indicated for child who remains 
febrile and dyspneic >72 hr after 
initiation of therapy with intravenous 
antibiotics and thoracostomy tube 
drainage 
N.B: 3VHXGRFK\ORXVHIIXVLRQ: Chronic serous effusion with cellular 
degeneration: 
 Criteria: - High cholesterol /Low triglycerides level. 
 
 
 - Doesn''t clear with ether or alkali. 
 
 - Doesn''t spread on filter paper 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1398),
   ('95d2e6bf-0899-5716-b295-a3c93c0dbe3e', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 199, 212, 0, 'Page | 3 
 Illustrated Baby Nelson 
199
 
 
 
Definition: Presence of both fluid & air in the pleural cavity. 
Causes 
 Thoracocentesis for pleural effusion o hydropeumothorax. 
 Thoracocentesis for hemothorax o hemopneumothorax. 
 Empyema with bronchopleural fistula o pyopneumothorax 
Clinical picture 
Chest examination 
- Inspection 
o Unilateral bulge. 
- Palpation 
o Decreased TVF & trachea shifted to opposite side. 
- Percussion 
o Shifting dullness. 
- Auscultation o Marked diminished breath sounds. 
 
 
 
o Succession splash 
Investigations 
- As pleural effusion; 
- Chest X-ray o air- fluid level 
 
 
 
 
 
 
 
 
 
 
 
 
 
Treatment 
1- Antibiotics according to culture and sensitivity. 
2- Closed drainage with underwater seal If failed o surgical closure of the 
fistula. 
 
Hydropneumothorax 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 902),
   ('84061b6e-f246-5ae3-a4eb-3401681a505e', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 200, 213, 0, 'Page | 2 Illustrated Baby Nelson 
200
 
 
 
 
 
Definition: Presence of air in the pleural cavity 
Causes 
 Rupture preumatoceles 
 Rupture tuberculous cavity 
 Rupture lung abscess. 
 Rupture surface alveoli in air trapping 
 Vigorous resuscitation 
 Chest wall trauma 
Clinical picture 
Symptoms 
 Asymptomatic (in small pneumothorax) o discovered accidentally 
 Symptomatic: o Respiratory distress (nn with tension pneumothorax). 
 
 
 o Symptoms of the cause 
Chest examination 
- Inspection 
o Unilateral decreased movement & unilateral bulge. 
- Palpation 
o Decreased TVF & trachea shifted to opposite side. 
- Percussion 
o Hyper resonance. 
- Auscultation o Marked diminished breath sounds. 
 
 
 
o Coin test 
Evidence of tension 
 Mediastinal shift 
 Circulatory compromise 
 Hearing a "hiss" of rapid exit of air under tension with the 
insertion of the thoracostomy tube 
Investigations 
 Chest X-ray/CT o jet black opacity 
± mediastinal shift to the opposite 
side 
 CT chest: may identify underlying 
pathology such as blebs 
 For the cause 
 
 
Treatment 
1- Small pneumothorax: usually resolve within 1 week. 
2- Symptomatic: 
- Closed drainage with underwater seal. 
- Tube is inserted in the 2nd space mid clavicular line. 
 3- Treat the underlying cause. 
Pneumothorax 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1391),
   ('61be1ede-b817-5f11-a6ca-3631a7aa0d6a', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 201, 214, 0, 'Page | 3 
 Illustrated Baby Nelson 
201
 
 
 
Definition 
Chronic infectious disease caused by Mycobacterium TB bacilli (human and 
bovine types) which is alcohol and acid fast aerobic intracellular bacilli. 
Modes of transmission 
 Inhalation o pulmonary tuberculosis 
 Ingestion(with milk) o intestinal T.B(& tonsillar tuberculosis) 
 Wound contamination o cutaneous tuberculosis 
 Hematological spread form primary T.B. focus 
Risk factors 
 Children exposed to high-risk adults 
 Low Socioeconomic standard (Homeless persons) 
 Suppressed immunity e.g. HIV, malnutrition & immunosuppressive therapy 
 Susceptible age: disease is more severe in infants and young child 
 Susceptible Race: More in Negroes 
Pathogenesis 
Primary exposure to T.B bacilli result in formation of primary complex at the 
site of entry of the bacilli (the commonest form in children). 
1. Primary pulmonary complex: 
 Composed of 
 Primary focus (Ghon''s focus) 
 Lymphangitis 
 Hilar lymphadenitis 
2. Primary cervical complex (tonsillar T.B) 
 Composed of 
 Primary focus in tonsils 
 Lymphangitis 
 Cervical lymphadenitis 
3. Primary intestinal complex 
 Composed of 
 Primary focus in pyere''s patches 
 Lymphangitis 
 Mesenteric lymphadenitis 
 
Each primary focus is formed of tubercles each tubercle is formed of : 
- Central caseation 
- Epitheloid cells 
- Macrophages and lymphocytes 
- Langerhans giant cells 
Tuberculosis 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1517),
   ('faa08b38-43e5-5dd6-952e-1d24fe73d66a', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 202, 215, 0, 'Page | 2 Illustrated Baby Nelson 
202
 
 
 
Fate of primary pulmonary complex 
 
 
With good immunity 
  
Regression (in 90%) 
x Small focus o complete fibrosis 
x Large focus o capsulation & calcification o 
In which T.B bacilli may remain viable 
for years ;Latent TB Infection ( LTBI) 
With poor immunity 
  
Progression 
N.B: Risk for progression of latent TB: Infants and children 4 
yr of age, especially those <2 yr of age, Adolescents and young 
adults, immunocompromised, and infection with measles 
and pertussis. 
 
 
Primary 
Cavitation 
Direct spread 
 
  
 T.B pneumonia 
 Tuberculous effusion 
 
Bronchial spread 
(Endobronchial T.B) 
   
 Incomplete obstruction 
 o emphysema 
 Complete obstruction 
 o collapse 
 Hematologic spread 
 
   
 One organ T.B 
 Miliary T.B 
 
Ț
 
 
 
 
 
 
 
 
(Nelson textbook of pediatrics, 2016) 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 946),
   ('dd94f800-2144-518b-8e30-c0c9cb11df89', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 203, 216, 0, 'Page | 3 
 Illustrated Baby Nelson 
203
 
Clinical Picture 
1.Pulmonary TB 
Common 
9 Asymptomatic in up to 50%; may be mild fatigue & poor appetite 
9 Nonproductive cough and mild dyspnea are the most common symptoms 
9 Some infants have difficulty gaining weight or frank failure-to-thrive 
May be 
 Hilar lymphadenopathy may present with: 
 Obstructive emphysema/wheezing: due to partial bronchial obstruction 
 Lung collapse: due to complete bronchial obstruction 
 Positive D''Espine sign (Bronchial breathing below level of tracheal 
bifurcation) 
 Wheezy chest : due to endobronchial TB with partial bronchial obstruction 
 Allergic manifestations: 
 
 
 
 
 
 
R Erythema nodosum 
R Phlyctenular keratoconjunctivitis 
 Toxic manifestations (uncommon) o night fever & sweating. 
 Manifestations of extension; usually with toxic manifestations and hectic 
fever e.g. Bronchopneumonia, tuberculous effusion, miliary tuberculosis 
N.B. Cough with sputum is rare, seen literally in progressive primary 
pulmonary TB with formation of T.B cavity. 
 
2. Extra pulmonary tuberculosis 
A. Tuberculous lymphadenopathy 
Common sites: Cervical, Mediastinal, Mesenteric 
Criteria: 
 Firm 
 Non-tender 
 Early discrete then matted after caseation 
Complications: 
 Cold abscess 
 Draining sinus 
Diagnosis: Biopsy and histologic examination 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1434),
   ('b87795fa-8af1-53c5-a74a-1a58da8b2a3a', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 204, 217, 0, 'Page | 2 
 Illustrated Baby Nelson 
204
 
B. Miliary tuberculosis 
 Hemtogenous spread of tubercle bacilli from any focus (usually 
pulmonary) o causing disease in 2 or more organs; lung, kidneys, liver, 
spleen, bone marrow meninges. 
 Usually complicates the primary infection, occurring within 2-6 mo of the
initial infection 
Common in 
Infants, malnourished, immunosuppressed, with measles or pertussis 
Clinical picture 
 Often, the onset is insidious, with anorexia, weight loss, and low-grade 
fever 
 Weeks later: 
 Generalized lymphadenopathy and hepatosplenomegaly 
 Fever higher and more sustained 
 Weeks later: 
 The lungs become filled with tuberclesĺ dyspnea, cough, rales, or
wheezing. May be respiratory distress, hypoxia, and pneumothorax 
 Meningitis (recurrent headache) or peritonitis (abdominal pain) are 
found in 20-40% 
 Cutaneous lesions include papulonecrotic 
tuberculids, nodules, or purpura 
Diagnosis 
1. History of recent exposure to an adult with 
infectious TBĺ The most important clue 
2. Biopsy of the liver or bone marrow with appropriate bacteriologic and 
histologic examinations more often yields an early diagnosis 
3. Chest x ray/CT: 
 Small miliary shadows; 
< 2-3 mm 
 (Snow storm opacities) 
 
4. Fundus examination: 
 Show choriod tubercles in 13-87 % 
 Highly specific 
5. TST is non-reactive in 40 % 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1449),
   ('b0cbde81-8dec-5f31-a9e8-75d3d79dec0d', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 205, 218, 0, 'Page | 3 
 Illustrated Baby Nelson 
205
 
C. Tuberculous meningitis 
 Complicates about 0.3% of untreated tuberculosis infections in children 
 Due to hematogenous spread either isolated or as a part of miliary TB
 Tubercle bacilli spreading into the subarachnoid space form a gelatinous 
exudate that infiltrates the corticomeningeal blood vessels, producing 
inflammation, obstruction, and subsequent infarction of cerebral cortex 
Clinical picture 
 - In infancy and early childhood
 - Insidious onset 
- Pass in 3 stages (each lasts 1-2 weeks)
 
 
 1st stage 
(Nonspecific) 
 Fever 
 Headache, irritability 
 Drowsiness, and 
malaise 
 2nd stage 
(Meningitis) 
 Meningeal irritation
 Ĺ Intra cranial tension 
 Cranial nerve palsies 
3rd stage 
(Terminal stage) 
 Hemiplegia or paraplegia
 Coma 
 Eventually death
D. Intestinal tuberculosis 
Occur secondary to 
 Ingested tubercle bacilli in milk 
 Swallowed sputum from tuberculous lesions in the lungs
Clinical picture 
 Tabes mesentrica; enlarged mesenteric lymph nodes. 
 Tuberculous enteritis: 
 Chronic diarrhea o failure to thrive
 Chronic abdominal pain 
E. Tuberculous peritonitis 
Occur 2ry to: Spread from intestinal or genitourinary T.B lesions 
Clinical picture 
 Ascites 
 May be adhesions. 
F. Pott''s disease 
Common sites: mainly affect lower dorsal spine.
Clinically 
 Back pain and stiffness
 Cold abscess formation with persistent angular kyphosis
X ray spine: Diagnostic 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1553),
   ('538beb77-bf78-5157-8def-e2bd935fb527', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 206, 219, 0, 'Page | 2 
 Illustrated Baby Nelson 
206
 
Diagnosis of tuberculosis
1. History of recent exposure to an adult with infectious TBĺ The most 
important clue 
2. Tuberculin Skin Test (TST): 
 Detects delayed hypersensitivity reaction to tuberculoprotein 
 Mantoux test: intradermal injection of 0.1 ml containing 5 tuberculin units
of purified protein derivative (PPD). 
 Interpretation: measure the induration after 48 -72 hours 

Indications : see later 
A. Positive test (= TB infection or disease) 
 1. Induration t 5 mm2 in high risk patients; 
 Close contact with active tuberculosis patient 
 Immunodeficiency 
 Child having clinical or chest x ray compatible 
with tuberculosis 
2. Induration t 10 mm2 in moderate risk patients; 
 Child < 4 years 
 Child from endemic area or exposed to people from endemic area 
 Chronic diseases with increased risk e.g. diabetes , renal diseases
 3. Induration t 15 mm2 in any child above 4 years without risk factors 
B. False positive test; usually less than 10 mm induration, consider: 
 Recent BCG vaccination; reactivity is lost by 5-10 years after vaccine 
 Non tuberculous mycobacteria 
C. Negative test: induration less than 5 mm2 
 True negative test o no T.B infection 
 False negative test o in 
 Technical error 
 Transient suppression of tuberculin reactivity with viral infections
e.g. measles, mumps or live virus immunization
 Early in the disease 
 Miliary TB. 
 Immunodeficiency 
3. Interferon-ȖRelease Assays (IGRA) 
 
 
Ț

 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1595),
   ('aca8165a-74bb-5a14-b038-1dc2a34e6ae0', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 207, 220, 0, 'Page | 3 
 Illustrated Baby Nelson 
207





Ӌ


Ӌ

(Nelson textbook of pediatrics, 2016) 
4. Specific: 
A. Pulmonary tuberculosis 
1. Isolate M. tuberculosis: 
Sampling 
 Expectorated sputum in older children 
 Induced sputum with a jet nebulizer and chest percussion followed by 
nasopharyngeal suctioning is effective in children as young as 1 year 
 3 consecutive early morning gastric aspirate before the infant has arisen 
Workup 
 Acid-fast bacilli staining (Zehl Nelsen stain and light microscopy) 
 Culture 
 Polymerase chain reaction ;PCR(of limited value) 
 Recently , Gene Xpert MTB/RIF is a real-time PCR assay for M. 
tuberculosis that simultaneously detects rifampin resistance 
Indications of TST or IGRA
1. Contacts of people with confirmed or suspected contagious TB 
2. Children with radiographic or clinical findings suggesting 
tuberculosis
3. Children immigrating from countries with endemic infection (e.g. 
Asia, Middle East)
4. Children with travel histories to countries with endemic infection
5. Children infected with HIV should have annual TST or IGRA
6. Before initiation of immunosuppressive therapy e.g. Prolonged 
steroid 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1257),
   ('833203a4-18d9-51c9-806a-caa1c8d16c1c', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 208, 221, 0, 'Page | 2 
 Illustrated Baby Nelson 
208
N.B For many forms of tuberculosis, the culture yield is only 25-50%. So,
negative cultures never exclude the diagnosis of tuberculosis in a child. 
2. Chest X-ray: May reveal
Enlarged hilar lymph nodes
Localized emphysema
Miliary TB; small miliary shadows 1-2
mm (snow flake opacities).
Enlarged hilar lymph nodes
Localized collapse
T.B bronchopneumonia ;fluffy cotton
appearance 
Pleural effusion 
Calcified granuloma (primary focus)
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 562),
   ('212ccbae-cbfb-50bb-8d80-725fe952734f', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 209, 222, 0, 'Page | 3 
 Illustrated Baby Nelson 
209
3. Detect the pathology: 
 Pleural biopsy 
 Lymph nodes biopsy
 Bronchoscopy (for suspected endobronchial TB)
and biopsy
4. Pleural fluid examination: 
 Color
 : Yellow with blood tinge 
 Characters: Usually unilateral, massive; recollect after aspiration 
 Cells : n lymphocytes but it is very rare to discover T.B bacilli 
 Cultures of the fluid are positive in <30% of cases. 
5. Blood: Elevated ESR
B. Tuberculous meningitis 
 Lumbar puncture and CSF analysis, culture and PCR(See neurology)
 CT, MRI may detect tuberculoma; a tumor-like mass resulting from 
aggregation of caseous tubercles 
N.B The TST is nonreactive in up to 50% of cases, and 20-50% of children
have a normal chest radiograph. 
C. Intestinal tuberculosis:
 Mesentric lymph node biopsy 
 Ascitic fluid analysis 
The presence of a positive TST or IGRA, an abnormal chest 
radiograph consistent with tuberculosis, and history of exposure to 
an adult with infectious tuberculosis is adequate for the probable 
diagnosis of tuberculosis disease
MRI of brain of a 3 yr old 
child showing multiple
pontine tuberculomas
(Nelson 2016)
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1239),
   ('b66e36f5-0e98-5247-b4ab-ee93a09d7689', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 210, 223, 0, 'Page | 2 
 Illustrated Baby Nelson 
210
 
Treatment 
Prevention 
* BCG vaccine (see before)
* Milk sanitation (boil milk for10- 15 minutes before use) 
* Isolate and treat infective cases with open pulmonary TB. 
* Avoid contact with cases. 
* Window prophylaxis:
 For children who: 
 Have unavoidable close contact to an adult with potentially contagious 
tuberculosis disease and 
 Have a negative TST or IGRA result 

Break the contact with the source case for tuberculosis (i.e. physical
separation or adequate initial treatment of the source case) and Give INH 
10 mg/kg/d for 3 months (the time delayed hypersensitivity develops) 

Perform TST or IGRA at 3 months 
 If positive result ( t 5 mm2 ) ĺ continue INH for 9 months 
 If negative resultĺVWRS INH and INH resistant BCG can be given 

Trace the possible adult source and treat adequately to prevent other 
secondary cases. 
Curative 
A. General lines 
 Good nutrition, fresh air 
 Follow up carefully to promote adherence to therapy, and to monitor for 
toxic reactions to medications 
B. Anti-Tuberclous drugs 
First line drugs 
 
Drug 
Daily 
dose* 
Twice weekly 
dose * 
Side effects 
 Isoniazide 
 (INH) 
10-15 
Double the 
dose 
- Hepatotoxic
- Peripheral neuritis (?? add vit B6)
 Rifampicin 
10-20 
Same 
- Hepatotoxic 
- Red staining of secretions
 Pyrazinamide 20-40 
50 
- Hepatotoxic 
- Hyperuricaemia
 Ethambutol 
20 
50 
- Optic neuritis (usually reversible) 
- Color blindness (green,red)
* mg/kg 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1576),
   ('58a9b74d-5692-56b8-a19e-7ac6b3e04462', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 211, 224, 0, 'Page | 3 
 Illustrated Baby Nelson 
211
 
Alternative drugs 
Used as additive drugs in 
 Multiple drug resistant tuberculosis 
 Life threatening tuberculosis e.g. T.B. meningitis.
Drug 
Dose (mg/kg/d) 
Side effects 
 Streptomycin
20-40 (I.M)
Ototoxic & nephrotoxic 
 Ethionamide
15-20 (oral)
Hepatotoxic (similar to INH). 
 Amikacin 
15-30 (IM) 
As streptomycin 
Regimens for treatment 
The specific treatment plan must be individualized for each patient according to 
the results of susceptibility testing on the isolates from the child or the adult 
source case 
1. Six months regimen 
 Standard therapy for intrathoracic tuberculosis and cervical
lymphadenopathy 

Rifampicin and INH (for 6 months) + Pyrazinamide and Ethambutol (in 
the1st 2 months) 
 
 
 When directly observed therapy is used: initial period as short as 2 wk of 
daily therapy followed by intermittent (twice weekly) therapy is as 
effective as daily therapy for the entire course. 
2. Nine month regimen 

Using only isoniazid and rifampin 
 Highly effective for drug-susceptible tuberculosis

Carry risk of initial drug resistance and poor compliance
3. In miliary T.B, meningitis and bone T.B 

Extend treatment period for 9-12 months.
4. In drug resistance 
 Treatment is undertaken by a clinician with specific expertise
 Initial treatment 
 Isoniazid resistance 9 mo with rifampin, pyrazinamide, and 
ethambutol 
 Isoniazid and rifampin resistance  extend total duration of therapy 
to 12-24mo, and avoid twice-a-week regimens 
5. Latent TB infection: isoniazid for 6-9 months 
Rifampicin + INH 
For 4 months 
1. Rifampicin 
2. INH 
3. Pyrazinamide 
4. Ethambutol 
For 2 months
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 1761),
   ('7486a8b0-00c1-59d7-a872-92fbe2586a47', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 212, 225, 0, 'Page | 2 Illustrated Baby Nelson 
212
 
 
 
Steroids in T.B 
Used in 
1- Miliary tuberculosis o to improve the general condition 
2- Endobronchial tuberculosis with localized emphysema. 
3- Enlarged hilar lymph nodes with airway obstruction. 
4- Tuberculosis of serous cavities e.g Pleurisy , Pericarditis , Meningitis 
5- Adrenal tuberculosis 
Precautions 
1- Under umbrella of antituberculous drugs. 
2- Dose 2 mg/kg/d for 4-6 weeks followed by gradual tapering. 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 552),
   ('476759c3-38b5-536e-a7d5-c33de79aa428', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 213, 226, 0, 'Page | 3 
 Illustrated Baby Nelson 
213
 
Respiratory failure 
 
Definition: Failure of the lungs to keep normal level of arterial blood gases( O2 & CO2) 
 
Peripheral(type I) 
Central (type II) 
Causes 
- Airway obstruction e.g asthma 
- Pneumonia 
- Pneumothorax 
- Massive effusion 
- Brain : hemorrhage,drugs 
- Neuromuscular: spinal muscle 
atrophy, Guillian Barre syndrome 
- Skeletal: severe kyphosis, scoliosis 
Clinically * Manifestations of the cause 
* Respiratory distress 
* Mainly hypoxemia: irritability 
restless, dizziness , cold pale 
extremities 
* Manifestations of the cause 
* Irregular , shallow respiration 
* Mainly hypercapnia: cyanosis, 
lethargy, headache and impaired 
consciousness 
ABGs 
pPaO2 - nPaCO2 - ppH 
Treatment Treat the cause 
Oxygen therapy(See neonates) 
Treat the cause 
Ventilation 
 
 .ﺟﻌﻠﻪ ﺍﻟﻠﻪ ﺻﺪﻗﺔ ﺟﺎﺭﻳﺔ ﻟﻲ ﻭﻟﻮﺍﻟﺪﻱ ﻭﻟﺬﺭﻳﺘﻲ
ﺭﻓﻌﻪ ﺩ. ﻣﺎﺟﺪ ﺍﻟﻤﻨﺼﻮﺭ. ﺩﻋﻮﺍﺗﻜﻢ
 
14 ﺍﻟﺪﻓﻌﺔ ﺍﻝ', 916)
  ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- extraction_job
-- -----------------------------------------------------------------------------
INSERT INTO knowledge.extraction_job (extraction_id, source_version_id, chapter_id, extraction_type, status) VALUES
   ('EXT-BN01', 'NELSON_ILLUSTRATED_2017', 'BN-C01', 'RESPIRATORY_METHOD', 'PENDING')
  ON CONFLICT DO NOTHING;
