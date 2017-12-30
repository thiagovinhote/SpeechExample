//
//  StoreSpeech.swift
//  SpeechExample
//
//  Created by Thiago Vinhote on 29/12/2017.
//  Copyright © 2017 Thiago Vinhote. All rights reserved.
//

import Speech

/// Tipo que será usado para retornar a chamada de forma assíncrona
typealias callback = (_ text: String?, _ error: Error?) -> Void

/// Completion usado na permissão do Speech Recognition
typealias completionPermission = (_ status: Bool, _ message: String) -> Void

// Mark - Classe
class StoreSpeech: NSObject {
    // Mark - Ciclo de vida
    
    /// Padrão Singleton
    /// - Instância única do objeto
    static let singleton = StoreSpeech()
    
    /// Realizarar o reconhecimento de fala real
    ///
    /// # Observação
    /// Por padrão, será detectado a localização do dispositivo e, em respota, reconhecerá o idioma apropriado para essa localização geográfica.
    ///
    ///
    /// Passando parâmetro
    ///
    ///     let s = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    ///
    /// Padrão
    ///
    ///     let s = SFSpeechRecognizer()
    fileprivate let speechRecognizer: SFSpeechRecognizer? = {
        return SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))!
    }()
    
    /// Para alocar o discurso como o usuário fala em tempo real e controlar o armazenamento em buffer
    fileprivate var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// Será usado para gerenciar, cancelar ou interromper a tarefa de reconhecimento corrente
    fileprivate var recognitionTask: SFSpeechRecognitionTask?
    
    /// Processa o fluxo de áudio
    /// - Dará atualizações quando o microfone receber áudio
    fileprivate let audioEngine: AVAudioEngine = {
        return AVAudioEngine()
    }()
    
    /// Guardar o resultado obtido do reconhecimento
    fileprivate var speechResult: SFSpeechRecognitionResult = {
        return SFSpeechRecognitionResult()
    }()
    
    // Ocultando o método construtor da classe
    private override init() {
        super.init()
    }
    
}

// Mark - Métodos publicos
extension StoreSpeech {
    
    /// Métodp para autorização do Speech Recognition
    ///
    /// Retorna um boolean de acesso é uma mensagem informando o status
    func requestPermission(completion: @escaping completionPermission) {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    completion(true, "Speech Recognition autorizado")
                    break
                case .notDetermined:
                    completion(false, "Speech Recognition não foi determinado")
                    break
                case .denied:
                    completion(false, "Usuário nego acesso ao Speech Recognition")
                    break
                case .restricted:
                    completion(false, "Speech Recognition restrito a este device")
                    break
                }
            }
        }
    }

    /// Método que dará inicio ao processo de reconhecimento da fala
    /// - Parameters:
    ///     - callback: Será chamado toda vez que um reconhecimento for processado. E em caso de erro será chamado.
    func startRecording(callback: @escaping callback) throws {
        
        // Verifica se já exite um processo de entrada de áudio
        if !audioEngine.isRunning {
            
            // Verificar disponibilidade para o dispositov e para a localidade
            // Caso não seja suportado este objeto estará nulo
            guard let speechRecognizer = speechRecognizer else {
                callback(nil, NSError())
                return
            }
            
            // Reconhecedor não está disponível agora
            if !speechRecognizer.isAvailable {
                callback(nil, NSError())
                return
            }
            
            // Criando objeto de requisição
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            // Mecanismo de áudio e reconhecimento de fala
            let inputNode = audioEngine.inputNode
            guard let recognitionRequest = recognitionRequest else {
                callback(nil, NSError())
                return
            }
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer , _) in
                recognitionRequest.append(buffer)
            }
            
            // Configure a solicitação para que os resultados sejam retornados antes da gravação de áudio terminar
            recognitionRequest.shouldReportPartialResults = true
            
            // Uma tarefa de reconhecimento é usada para sessões de reconhecimento de fala
            // Uma referência para a tarefa é salva para que possa ser cancelada
            // É aí que o reconhecimento acontece. O áudio está sendo enviado para um servidor Apple e, em seguida, retorna como resultado, objeto com atributos
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                
                if let result = result {
                    self.speechResult = result
                    
                    // Usar: result.bestTranscription.formattedString, para formatar o resultado como um valor de sequência de caracteres
                    callback(result.bestTranscription.formattedString, nil)
                }
                
                // Caso algo acontecá de errado
                if error != nil {
                    // Parar o reconhecimento
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    
                    self.recognitionRequest = nil
                    self.recognitionTask?.cancel()
                    self.recognitionTask = nil
                    
                    callback(nil, error)
                }
                
            }
            
            // Preparar e começar a gravação usando o mecanismo de áudio
            // O try está lançando a exceção para quem chama o `startRecording`
            audioEngine.prepare()
            try audioEngine.start()
        }
    }
    
    /// Método para cancelar o reconhecimento
    /// Todos o processos são paradas e objetos são setados com `nil`
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
}

