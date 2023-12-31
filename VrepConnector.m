classdef VrepConnector
    properties
        sim;                % similar to fd
        clientID;           % for server connection and server requests
        robot_joints = []   % list of joint handles
        step_time_vrep;     % integration step used for simulation
    end

    methods
        % constructor
        function obj = VrepConnector(port, step_time_vrep)
            addpath vrep_lib/;                      % add APIs to the path
            obj.step_time_vrep = step_time_vrep;
            obj.sim = remApi('remoteApi');          % remoteAPI object
            obj.sim.simxFinish(-1);
            obj.clientID = obj.sim.simxStart('127.0.0.1', port, true, true, 5000, 5);
            if (obj.clientID > -1)
                disp('Connected to simulator');
            else
                disp('Error in connection');
            end
            % enable the synchronous mode on the client: (integration step on
            % call)
            obj.sim.simxSynchronous(obj.clientID, true);
            % start the simulation
            obj.sim.simxStartSimulation(obj.clientID, obj.sim.simx_opmode_blocking);
            for i = 1:7
                [~, obj.robot_joints(i)] = obj.sim.simxGetObjectHandle(obj.clientID, ...
                    strcat('LBR_iiwa_14_R820_joint', int2str(i)), obj.sim.simx_opmode_blocking);
            end
            for i = 1:7
                [~, joint_pos] = obj.sim.simxGetJointPosition(obj.clientID, obj.robot_joints(i), ...
                    obj.sim.simx_opmode_streaming);
            end
        end
        
        % finish program
        function Close(obj)
            obj.sim.simxStopSimulation(obj.clientID, obj.sim.simx_opmode_blocking);
            disp('Close program');
            obj.sim.simxFinish(-1);
            obj.sim.delete();
        end
        
        % apply the controller
        function ApplyControl(obj, u, delta_t)
            for i = 1:7
                obj.sim.simxSetJointTargetVelocity(obj.clientID, obj.robot_joints(i), ...
                    u(i), obj.sim.simx_opmode_oneshot);
            end
            for i = 1:(delta_t/obj.step_time_vrep) % number of integrations
                obj.sim.simxSynchronousTrigger(obj.clientID); % trigger the integration
                % to overcaome delay in values according to document
            end
            obj.sim.simxGetPingTime(obj.clientID); % synchronizing
        end

        % get current robot joint position
        function q = GetState(obj)
            q = zeros(1, 7);
            for i = 1:7
                [~, q(i)] = obj.sim.simxGetJointPosition(obj.clientID, obj.robot_joints(i), ...
                    obj.sim.simx_opmode_buffer);
            end
        end
    end
end