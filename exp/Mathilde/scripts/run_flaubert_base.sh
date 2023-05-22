#!/usr/bin/bash

#SBATCH --job-name=flaubert_base_no_sense_comp
#SBATCH -A czj@v100  # TODO à changer !! 
#SBATCH -C v100-32g  # TODO à changer !! 
#SBATCH --gres=gpu:1
#SBATCH --ntasks=8
#SBATCH --qos=qos_gpu-t3
#SBATCH --time=20:00:00
#SBATCH --output=flaubert_base_no_sense_comp

cd /home/getalp/aguiarm/WSD/nwsd  

# ----- VARIABLE TO DEFINE ----- #
BASE_PATH=/home/getalp/aguiarm/WSD/nwsd  # TODO à changer quand sur Jean Zay 
SEMCOR_PATH=$BASE_PATH/data/corpora/semcor.fr.xml # path of the SEMCOR data
WNGT_PATH=$BASE_PATH/data/corpora/wngt.fr.xml # path of the WNGT data
BERT_PATH=$BASE_PATH/pt_models/flaubert_base_cased
TEST_DATA=$BASE_PATH/data/corpora/semeval2013task12.fr.xml
DATA_DIRECTORY=$BASE_PATH/data/PREPROCESSED # to store the prepared data
TARGET_DIRECTORY=$BASE_PATH/trained_models/flaubert_base_no_sense_comp # to store the trained model
TXT_TO_WSD=$BASE_PATH/data/to_disambiguate
WEIGHTS_PATH=$BASE_PATH/trained_models/flaubert_base_no_sense_comp/model_weights_wsd0

# ----- CHECK IF DIRECTORIES EXIST ----- #
if [ ! -d "$DATA_DIRECTORY" ]; then
  # Create the folder if it doesn't exist
  mkdir "$DATA_DIRECTORY"
  echo "Folder $DATA_DIRECTORY created."
else
  echo "Folder $DATA_DIRECTORY already exists."
fi

if [ ! -d "$TARGET_DIRECTORY" ]; then
  # Create the folder if it doesn't exist
  mkdir "$TARGET_DIRECTORY"
  echo "Folder $TARGET_DIRECTORY created."
else
  echo "Folder $TARGET_DIRECTORY already exists. Will be override !"
fi

echo "---------- Preparing the data ----------"
# ------ Prepare the data to train a Neural Word Sense Disambiguation model ------ #
# NOTE: ATTENTION!! À NE FAIRE QUE 1 FOIS 
python src/NeuralWSDPrepare.py \
--data_path $DATA_DIRECTORY \
--train $SEMCOR_PATH $WNGT_PATH \
--dev_from_train 4000 \
--input_clear_text True \
--sense_compression_hypernyms False \
--lowercase True 

echo "---------- Preparation of the data done, starting the training ----------"

# ------ Train the Neural Word Sense Disambiguation model ------ #
python src/train.py --data_path $DATA_DIRECTORY \
--model_path $TARGET_DIRECTORY \
--batch_size 100 --token_per_batch 2000 --update_frequency 4 \
--eval_frequency 9999999 --ensemble_count 1 --epoch_count 50 \
--input_auto_model flaubert --input_auto_path $BERT_PATH \
--encoder_type transformer \
--encoder_transformer_hidden_size 768 \
--encoder_transformer_layers 12 \
--encoder_transformer_heads 12 \
--encoder_transformer_dropout 0.1 \
--encoder_transformer_positional_encoding true \
--encoder_transformer_scale_embeddings false

echo "---------- Training done, starting the evaluation ----------"

# ------ Evaluate the Neural Word Sense Disambiguation model ------ #
python src/NeuralWSDEvaluate.py \
--data_path $DATA_DIRECTORY \
--weights $WEIGHTS_PATH \
--corpus $TEST_DATA \
--lowercase True \
--sense_compression_hypernyms False \
--filter_lemma False \
--clear_text False

echo "---------- Evaluation done, starting the disambiguation of pictos ----------"

dir_model="$(dirname "$WEIGHTS_PATH")"
mkdir "$dir_model/pictos"
PICTO_PATH="$dir_model/pictos"

python src/NeuralWSDDecodePictos.py \
--data_path $DATA_DIRECTORY \
--weights $WEIGHTS_PATH \
--lowercase True \
--sense_compression_hypernyms False \
--filter_lemma False \
--clear_text False \
--corpus /gpfswork/rech/czj/uef37or/nwsd/data/corpora/corpus_txt_pictos_ids_wn_300.csv \
--saved_path $PICTO_PATH \
--mfs_backoff False

# ------ Disambiguate sentences with the Neural Word Sense Disambiguation model ------ #
# python src/NeuralWSDDecode.py \
# --data_path $DATA_DIRECTORY \
# --weights $WEIGHTS_PATH \
# --lowercase True \
# --sense_compression_hypernyms False \
# --filter_lemma False \
# --clear_text False \
# --mfs_backoff False < $TXT_TO_WSD
