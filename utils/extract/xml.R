# ==========================
# Chargement des bibliothèques nécessaires
# ==========================
library(xml2)      # Pour lire et manipuler des fichiers XML
library(dplyr)     # Pour manipuler les tableaux de données (tibbles)
library(purrr)     # Pour les fonctions de programmation fonctionnelle (map, walk, etc.)
library(stringr)   # Pour manipuler les chaînes de caractères
library(tibble)    # Pour créer des objets tibbles (données tabulaires modernes)

# ==========================
# Fonction : convert_xml_file_To_Tibble
# Objectif : Convertir un document XML en une liste de tables (tibbles) classées par type d'objet
# ==========================
convert_xml_file_To_Tibble <- function(doc, select_clas = NULL) {
  tryCatch({

    # --- Étape 1 : Vérification et conversion de l'objet XML ---
    if (!inherits(doc, "xml_document")) {
      doc <- as_xml_document(doc)
      cat("L'entrée a été convertie en un objet xml_document \n")
    }

    root <- xml_root(doc)
    if (is.null(root)) {
      warning("Le document XML est vide")
      return(list())
    }

    # --- Étape 2 : Préparer le filtre de sélection ---
    select_pattern <- as.character(select_clas %||% character(0))
    has_selection <- length(select_pattern) > 0

    # --- Étape 3 : Initialiser le conteneur de résultats ---
    tables <- list()

    # --- Étape 4 : Fonction récursive de parcours des noeuds <obj> ---
    parse_obj <- function(node) {
      tryCatch({
        clas <- xml_attr(node, "clas")
        if (is.na(clas) || is.null(clas)) return()

        # Si sélection active, ignorer les noeuds non correspondants
        if (has_selection) {
          keep <- str_detect(clas, regex(select_pattern, ignore_case = TRUE))
          if (!keep) return()
        }

        # Extraire les propriétés de type <prop> sans sous-éléments
        props <- xml_find_all(node, "./prop[not(*) and not(.//obj)]")
        if (length(props) == 0) return()

        texts <- xml_text(props) %>% trimws()
        names <- xml_attr(props, "nom") %>% str_remove("^\\$")

        # Vérification cohérence nom/valeur
        if (length(texts) != length(names)) {
          warning(sprintf("Incohérence dans %s : %d valeurs / %d noms",
                          clas, length(texts), length(names)))
          return()
        }

        # Création d'une ligne de données nommée
        row <- set_names(texts, names)

        # Ajout de la ligne à la bonne table
        if (is.null(tables[[clas]])) tables[[clas]] <<- tibble()
        tables[[clas]] <<- tryCatch(
          bind_rows(tables[[clas]], as_tibble_row(row)),
          error = function(e) {
            warning(sprintf("bind_rows échoue pour %s : %s", clas, e$message))
            tables[[clas]]
          }
        )

        # Parcours récursif des objets enfants
        children <- c(xml_find_all(node, "./prop//obj"),
                      xml_find_all(node, "./prop//entr/obj"))
        walk(children, parse_obj)

      }, error = function(e) {
        warning(sprintf("Erreur lors du traitement du nœud : %s", e$message))
      })
    }

    # --- Étape 5 : Démarrer l'extraction à partir des objets <obj> ---
    objs <- tryCatch(xml_find_all(root, ".//obj"),
                     error = function(e) xml_nodeset())
    if (length(objs)) walk(objs, parse_obj)

    # --- Étape 6 : Nettoyer les noms de colonnes (supprimer les caractères non alphanumériques) ---
    tables <- map(tables, ~ tryCatch(
      rename_with(., ~ str_replace_all(.x, "[^[:alnum:]_]", "")),
      error = function(e) .
    ))

    cat("Conversion terminée\n")
    return(tables)

  }, error = function(e) {
    warning("Erreur globale :", e$message)
    return(list())
  })
}

# ==========================
# Fonction : convert_Xmlfiles_Data_ToTbl
# Objectif : Convertir une liste de fichiers XML en une liste de tables unifiées (fusionnées par classe)
# ==========================
convert_Xmlfiles_Data_ToTbl <- function(files, select_clas = NULL) {
  # Appliquer la conversion à chaque fichier
  data <- lapply(files, function(file) {
    file |> convert_xml_file_To_Tibble(select_clas)
  })

  # Fusionner les tables par nom de classe (clé de liste)
  tbls <- lapply(names(data[[1]]), function(tblName) {
    map_dfr(data, tblName)
  })
  names(tbls) <- names(data[[1]])
  return(tbls)
}
# ==========================
# Fonction : convert_To_XmlFiles
# Objectif : Convertir une liste de chaînes ou objets texte en objets xml_document
# ==========================
convert_To_XmlFiles <- function(files) {
  xml_files <- lapply(files, function(file) {
    file |> xml2::as_xml_document()
  })
  return(xml_files)
}
convert_Xmlfiles_Data_from_tableToTbls <- function(files, select_clas = NULL, parentName = NULL, parentIDS = NULL) {
  # Vérifier que parentName et parentIDS sont fournis ensemble
  if (is.null(parentName) || is.null(parentIDS)) {
    stop("parentName et parentIDS doivent être fournis ensemble ou non fournis du tout")
  }

  # Vérifier que files et parentIDS ont la même longueur si parentIDS est fourni
  if (!is.null(parentIDS) && length(files) != length(parentIDS)) {
    stop("La longueur de 'files' doit être égale à celle de 'parentIDS'")
  }

  # Appliquer la conversion à chaque fichier avec son ID parent associé
  data <- lapply(seq_along(files), function(i) {
    tbls <- convert_xml_file_To_Tibble(files[[i]], select_clas)
    
    # Ajouter la colonne parent si parentName et parentIDS sont fournis
    if (!is.null(parentName) && !is.null(parentIDS)) {
      tbls <- lapply(tbls, function(tbl) {
        if (is.data.frame(tbl) && nrow(tbl) > 0) {
          tbl[[parentName]] <- parentIDS[[i]]
          tbl
        } else {
          tbl
        }
      })
    }
    tbls
  })

  # Fusionner les tables par nom de classe (clé de liste)
  tbls <- lapply(names(data[[1]]), function(tblName) {
    map_dfr(data, tblName)
  })
  
  names(tbls) <- names(data[[1]])
  return(tbls)
}


bind_tables_about <- function(lst, prefix) {
  # Vérifier que lst est bien une liste

  if (is.list(lst)==FALSE) {
    stop("L'argument 'lst' doit être une liste.")
  }
 

  # Filtrer les noms commençant par le préfixe donné
  matching_names <- names(lst)[startsWith(names(lst), prefix)]
 
  if (length(matching_names) == 0) {
    warning(paste("Aucun élément trouvé avec le préfixe :", prefix))
    return(NULL)
  }

  # Extraire les tibbles correspondants
  tibbles <- lst[matching_names]

  # Vérifier que tous les éléments sont des tibbles ou des data.frames
  if (!all(sapply(tibbles, is.data.frame))) {
    stop("Tous les éléments sélectionnés doivent être des data.frames ou des tibbles.")
  }

  # Combiner les tibbles
  result <- bind_rows(tibbles, .id = "source") # .id ajoute une colonne source avec les noms

  return(result)
}